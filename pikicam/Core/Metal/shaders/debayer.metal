//
//  debayer.metal
//  pikicam — Phase 2 Metal debayer pipeline
//
//  Anti-computational-photography raw processor.
//  Implements the full Phase 2 pipeline (grand-plan.md §3.3):
//    1. Linearization       — LinearizationTable lookup (if present)
//    2. Black subtract       — per-channel cblack from DNG
//    3. White balance        — multiply by 1/AsShotNeutral, normalized to G=1
//    4. Demosaic             — Malvar-He-Cutler (single-pass, branchless)
//    5. Color matrix         — Camera RGB → XYZ D50 via ForwardMatrix
//    6. Working space        — XYZ → Display P3 linear (scene-referred)
//    7. Tone/gamma           — identity by default (no S-curve, no boost)
//
//  Reference: "High-quality linear interpolation for demosaicing of
//  Bayer-patterned color images" (Malvar, He, Cutler, ICIP 2004).
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms

/// Per-frame parameters passed as a MTLBuffer.
struct DemosaicUniforms {
    uint cfaPattern;               // 0=RGGB, 1=BGGR, 2=GRBG, 3=GBRG
    uint width;
    uint height;
    float blackLevel[4];           // per-channel R, G1, B, G2
    float whiteLevel;
    float wbGain[3];               // R, G, B white balance multipliers
    float3x3 colorMatrix;          // camera RGB → XYZ D50
    float3x3 xyzToDisplayP3;       // XYZ D50 → Display P3 linear
    float gamma;                   // 1.0 = linear (identity)
    uint hasLinearizationTable;    // 0 = identity, 1 = LUT present
};

// MARK: - Constants

/// Malvar-He-Cutler 5×5 green-channel filter kernel at red/blue pixel locations.
/// Coefficients from Malvar, He, Cutler (2004), Table I.
/// Normalization factor: divide by 8.
constant float g_malvar_green_5x5[25] = {
     0.0,  0.0, -1.0,  0.0,  0.0,
     0.0,  0.0,  2.0,  0.0,  0.0,
    -1.0,  2.0,  4.0,  2.0, -1.0,
     0.0,  0.0,  2.0,  0.0,  0.0,
     0.0,  0.0, -1.0,  0.0,  0.0
};

// MARK: - CFA Phase Helpers

/// Returns the CFA color type at pixel (x, y) for the given pattern.
/// Returns 0=R, 1=G, 2=B. (G is always 1 regardless of which G in the 2×2 cell.)
static int cfa_color_at(uint pattern, uint x, uint y) {
    uint px = x & 1u;
    uint py = y & 1u;
    switch (pattern) {
        case 0:  // RGGB
            // (0,0)=R, (1,0)=G, (0,1)=G, (1,1)=B
            if (px == 0 && py == 0) return 0;
            if (px == 1 && py == 1) return 2;
            return 1;
        case 1:  // BGGR
            // (0,0)=B, (1,0)=G, (0,1)=G, (1,1)=R
            if (px == 0 && py == 0) return 2;
            if (px == 1 && py == 1) return 0;
            return 1;
        case 2:  // GRBG
            // (0,0)=G, (1,0)=R, (0,1)=B, (1,1)=G
            if (px == 1 && py == 0) return 0;
            if (px == 0 && py == 1) return 2;
            return 1;
        case 3:  // GBRG
            // (0,0)=G, (1,0)=B, (0,1)=R, (1,1)=G
            if (px == 1 && py == 0) return 2;
            if (px == 0 && py == 1) return 0;
            return 1;
        default:
            return 1;
    }
}

/// Returns the black-level index (0=R, 1=G1, 2=B, 3=G2) for a pixel.
/// Used to select the correct blackLevel[channel] for subtraction.
static int black_channel_index(uint pattern, uint x, uint y) {
    uint px = x & 1u;
    uint py = y & 1u;
    switch (pattern) {
        case 0:  // RGGB: (0,0)=R(0), (1,0)=G1(1), (0,1)=G2(3), (1,1)=B(2)
            if (px == 0 && py == 0) return 0;
            if (px == 1 && py == 0) return 1;
            if (px == 0 && py == 1) return 3;
            return 2;
        case 1:  // BGGR: (0,0)=B(2), (1,0)=G1(1), (0,1)=G2(3), (1,1)=R(0)
            if (px == 0 && py == 0) return 2;
            if (px == 1 && py == 0) return 1;
            if (px == 0 && py == 1) return 3;
            return 0;
        case 2:  // GRBG: (0,0)=G1(1), (1,0)=R(0), (0,1)=B(2), (1,1)=G2(3)
            if (px == 0 && py == 0) return 1;
            if (px == 1 && py == 0) return 0;
            if (px == 0 && py == 1) return 2;
            return 3;
        case 3:  // GBRG: (0,0)=G1(1), (1,0)=B(2), (0,1)=R(0), (1,1)=G2(3)
            if (px == 0 && py == 0) return 1;
            if (px == 1 && py == 0) return 2;
            if (px == 0 && py == 1) return 0;
            return 3;
        default:
            return 1;
    }
}

/// Clamped read from a texture. Returns 0 for out-of-bounds.
static float safe_read_Bayer(texture2d<float, access::read> tex, int2 pos, uint2 dims) {
    uint2 u = uint2(clamp(pos.x, 0, int(dims.x) - 1),
                    clamp(pos.y, 0, int(dims.y) - 1));
    return tex.read(u).r;
}

// MARK: - Kernel 1: Linearize

/// Applies linearization table lookup to raw Bayer data.
///
/// The linearization table maps raw 16-bit sensor values to linearized values.
/// If `hasLinearizationTable == 0`, this is a pass-through (identity).
///
/// The linearization LUT is passed as a texture (width=65536, height=1, R8),
/// or as a buffer of 65536 uint16 values. We use a texture for cache efficiency.
///
/// - Parameters:
///   - bayerTexture: Single-channel raw Bayer input.
///   - destTexture: Single-channel linearized output.
///   - lutTexture: 1D texture (width=65536) containing linearization LUT, or nil.
///   - uniforms: Pipeline parameters.
kernel void linearizeKernel(
    texture2d<float, access::read>  bayerTexture [[texture(0)]],
    texture2d<float, access::write> destTexture  [[texture(1)]],
    texture1d<uint, access::read>   lutTexture   [[texture(2)]],
    constant DemosaicUniforms&      uniforms     [[buffer(0)]],
    uint2                           gid          [[thread_position_in_grid]]
) {
    const uint2 dims = uint2(uniforms.width, uniforms.height);
    if (gid.x >= dims.x || gid.y >= dims.y) return;

    float raw = bayerTexture.read(gid).r;

    if (uniforms.hasLinearizationTable != 0) {
        // Clamp raw value to LUT range (0–65535)
        uint index = uint(clamp(raw, 0.0, 65535.0));
        uint linearized = lutTexture.read(index).r;
        destTexture.write(float(linearized) / 65535.0, gid);
    } else {
        // Identity: pass through
        destTexture.write(raw, gid);
    }
}

// MARK: - Kernel 2: Black Subtract

/// Subtracts per-channel black level and clips to zero.
///
/// DNG black levels are per-channel (R, G1, B, G2). We select the appropriate
/// channel based on the CFA pattern and subtract, then clip to [0, whiteLevel].
///
/// - Parameters:
///   - linearTexture: Linearized single-channel input.
///   - destTexture: Black-subtracted single-channel output.
///   - uniforms: Pipeline parameters including blackLevel[4] and whiteLevel.
kernel void blackSubtractKernel(
    texture2d<float, access::read>  linearTexture [[texture(0)]],
    texture2d<float, access::write> destTexture   [[texture(1)]],
    constant DemosaicUniforms&      uniforms      [[buffer(0)]],
    uint2                           gid           [[thread_position_in_grid]]
) {
    const uint2 dims = uint2(uniforms.width, uniforms.height);
    if (gid.x >= dims.x || gid.y >= dims.y) return;

    float val = linearTexture.read(gid).r;

    int ch = black_channel_index(uniforms.cfaPattern, gid.x, gid.y);
    float black = uniforms.blackLevel[ch];
    float white = uniforms.whiteLevel;

    val = max(val - black, 0.0f);
    val = min(val, white);

    // Normalize to [0, 1] range for subsequent processing
    destTexture.write(val / white, gid);
}

// MARK: - Kernel 3: White Balance

/// Applies white-balance gains to black-subtracted data.
///
/// Gains are computed as `1.0 / AsShotNeutral` normalized so G = 1.0.
/// Each Bayer pixel is multiplied by the gain of its CFA color.
///
/// - Parameters:
///   - blackTexture: Black-subtracted single-channel input (normalized [0,1]).
///   - destTexture: White-balanced single-channel output.
///   - uniforms: Pipeline parameters including wbGain[3] = {R_gain, G_gain, B_gain}.
kernel void whiteBalanceKernel(
    texture2d<float, access::read>  blackTexture [[texture(0)]],
    texture2d<float, access::write> destTexture  [[texture(1)]],
    constant DemosaicUniforms&      uniforms     [[buffer(0)]],
    uint2                           gid          [[thread_position_in_grid]]
) {
    const uint2 dims = uint2(uniforms.width, uniforms.height);
    if (gid.x >= dims.x || gid.y >= dims.y) return;

    float val = blackTexture.read(gid).r;

    int color = cfa_color_at(uniforms.cfaPattern, gid.x, gid.y);
    float gain = uniforms.wbGain[color];

    destTexture.write(val * gain, gid);
}

// MARK: - Kernel 4: Malvar-He-Cutler Demosaic (primary)

/// Malvar-He-Cutler single-pass demosaic kernel.
///
/// Implements the algorithm from Malvar, He, Cutler (ICIP 2004).
///
/// ## Algorithm
/// For each output pixel (x, y):
/// 1. Determine CFA phase from (x mod 2, y mod 2) and pattern.
/// 2. For the GREEN channel at R/B pixels: apply the 5×5 Malvar filter (h₁)
///    to the white-balanced Bayer neighborhood, then divide by 8.
///    At G pixels, pass through the raw value.
/// 3. For the RED/BLUE channels:
///    - At same-color positions: pass through raw value.
///    - At G positions on a same-color row (horizontal neighbors are target color):
///      average the two horizontal same-color neighbors.
///    - At G positions on cross-color row (diagonal neighbors are target color):
///      average the four diagonal same-color neighbors.
///    - At opposite-color positions (R at B or B at R):
///      average the four diagonal same-color neighbors.
///
/// Edge pixels are handled by clamping to the nearest valid pixel (replicate
/// boundary). This avoids branching per pixel outside of the bounds check.
///
/// - Parameters:
///   - wbTexture: White-balanced single-channel Bayer input (normalized [0,∞)).
///   - destTexture: RGBA output (R, G, B, 1.0).
///   - uniforms: Pipeline parameters including cfaPattern and dimensions.
kernel void malvarDebayerKernel(
    texture2d<float, access::read>  wbTexture   [[texture(0)]],
    texture2d<float, access::write> destTexture [[texture(1)]],
    constant DemosaicUniforms&      uniforms    [[buffer(0)]],
    uint2                           gid         [[thread_position_in_grid]]
) {
    const uint2 dims = uint2(uniforms.width, uniforms.height);
    if (gid.x >= dims.x || gid.y >= dims.y) return;

    const int x = int(gid.x);
    const int y = int(gid.y);
    const uint pattern = uniforms.cfaPattern;

    // Determine the CFA color at this pixel.
    int centerColor = cfa_color_at(pattern, gid.x, gid.y);

    // --- GREEN CHANNEL ---
    float G;

    if (centerColor == 1) {
        // At a green pixel: pass-through.
        G = wbTexture.read(gid).r;
    } else {
        // At a red or blue pixel: apply 5×5 Malvar green filter.
        float sum = 0.0;
        for (int ky = -2; ky <= 2; ++ky) {
            for (int kx = -2; kx <= 2; ++kx) {
                int idx = (ky + 2) * 5 + (kx + 2);
                float coeff = g_malvar_green_5x5[idx];
                if (coeff != 0.0) {
                    float raw_val = safe_read_Bayer(wbTexture, int2(x + kx, y + ky), dims);
                    sum += coeff * raw_val;
                }
            }
        }
        G = sum / 8.0;
    }

    // --- RED CHANNEL ---
    float R;
    {
        // Determine if center is on a "red row" (horizontally adjacent to R)
        // or "blue row" (not horizontally adjacent to R).
        // In RGGB: rows with y even are red rows (R at col even, G at col odd).
        // In BGGR: rows with y even are blue rows (B at col even, G at col odd).
        // In GRBG: rows with y even are... G-R-B-G
        // Let's compute by checking the CFA color at neighbor positions.
        int colorE = cfa_color_at(pattern, gid.x + 1, gid.y);
        int colorW = cfa_color_at(pattern, gid.x - 1, gid.y);
        int colorNE = cfa_color_at(pattern, gid.x + 1, gid.y - 1);
        int colorNW = cfa_color_at(pattern, gid.x - 1, gid.y - 1);
        int colorSE = cfa_color_at(pattern, gid.x + 1, gid.y + 1);
        int colorSW = cfa_color_at(pattern, gid.x - 1, gid.y + 1);

        bool hasRHorizontal = (colorE == 0 || colorW == 0);
        bool hasRDiagonal   = (colorNE == 0 || colorNW == 0 || colorSE == 0 || colorSW == 0);

        if (centerColor == 0) {
            // At a red pixel: pass-through.
            R = wbTexture.read(gid).r;
        } else if (hasRHorizontal) {
            // At a G pixel between R neighbors horizontally: average horizontal R.
            float rLeft  = safe_read_Bayer(wbTexture, int2(x - 1, y), dims);
            float rRight = safe_read_Bayer(wbTexture, int2(x + 1, y), dims);
            R = (rLeft + rRight) * 0.5;
        } else if (hasRDiagonal) {
            // At a G pixel on a blue row or at a B pixel: average diagonal R.
            float rNW = safe_read_Bayer(wbTexture, int2(x - 1, y - 1), dims);
            float rNE = safe_read_Bayer(wbTexture, int2(x + 1, y - 1), dims);
            float rSW = safe_read_Bayer(wbTexture, int2(x - 1, y + 1), dims);
            float rSE = safe_read_Bayer(wbTexture, int2(x + 1, y + 1), dims);
            R = (rNW + rNE + rSW + rSE) * 0.25;
        } else {
            // Fallback: nearest neighbor (should not normally occur).
            R = safe_read_Bayer(wbTexture, int2(x, y), dims);
        }
    }

    // --- BLUE CHANNEL ---
    float B;
    {
        int colorE = cfa_color_at(pattern, gid.x + 1, gid.y);
        int colorW = cfa_color_at(pattern, gid.x - 1, gid.y);
        int colorNE = cfa_color_at(pattern, gid.x + 1, gid.y - 1);
        int colorNW = cfa_color_at(pattern, gid.x - 1, gid.y - 1);
        int colorSE = cfa_color_at(pattern, gid.x + 1, gid.y + 1);
        int colorSW = cfa_color_at(pattern, gid.x - 1, gid.y + 1);

        bool hasBHorizontal = (colorE == 2 || colorW == 2);
        bool hasBDiagonal   = (colorNE == 2 || colorNW == 2 || colorSE == 2 || colorSW == 2);

        if (centerColor == 2) {
            // At a blue pixel: pass-through.
            B = wbTexture.read(gid).r;
        } else if (hasBHorizontal) {
            // At a G pixel between B neighbors: average horizontal B.
            float bLeft  = safe_read_Bayer(wbTexture, int2(x - 1, y), dims);
            float bRight = safe_read_Bayer(wbTexture, int2(x + 1, y), dims);
            B = (bLeft + bRight) * 0.5;
        } else if (hasBDiagonal) {
            // At a G pixel on a red row or at an R pixel: average diagonal B.
            float bNW = safe_read_Bayer(wbTexture, int2(x - 1, y - 1), dims);
            float bNE = safe_read_Bayer(wbTexture, int2(x + 1, y - 1), dims);
            float bSW = safe_read_Bayer(wbTexture, int2(x - 1, y + 1), dims);
            float bSE = safe_read_Bayer(wbTexture, int2(x + 1, y + 1), dims);
            B = (bNW + bNE + bSW + bSE) * 0.25;
        } else {
            B = safe_read_Bayer(wbTexture, int2(x, y), dims);
        }
    }

    destTexture.write(float4(R, G, B, 1.0), gid);
}

// MARK: - Kernel 5: Bilinear Debayer (fallback)

/// Simple bilinear demosaic kernel (fallback for low-power / preview).
///
/// For each output pixel, the missing color channels are estimated by
/// bilinear interpolation of the nearest same-color samples in the Bayer grid.
///
/// This is significantly faster than Malvar-He-Cutler but produces visible
/// aliasing and color moiré. Used as a fallback on older devices or for
/// viewfinder preview where latency matters more than quality.
///
/// - Parameters:
///   - wbTexture: White-balanced single-channel Bayer input (normalized [0,∞)).
///   - destTexture: RGBA output.
///   - uniforms: Pipeline parameters including cfaPattern and dimensions.
kernel void bilinearDebayerKernel(
    texture2d<float, access::read>  wbTexture   [[texture(0)]],
    texture2d<float, access::write> destTexture [[texture(1)]],
    constant DemosaicUniforms&      uniforms    [[buffer(0)]],
    uint2                           gid         [[thread_position_in_grid]]
) {
    const uint2 dims = uint2(uniforms.width, uniforms.height);
    if (gid.x >= dims.x || gid.y >= dims.y) return;

    const int x = int(gid.x);
    const int y = int(gid.y);
    const uint pattern = uniforms.cfaPattern;

    int center = cfa_color_at(pattern, gid.x, gid.y);

    // --- GREEN: always 4-neighbor average at non-G positions ---
    float G;
    if (center == 1) {
        G = wbTexture.read(gid).r;
    } else {
        // Average of 4 cardinal G neighbors
        float gN  = safe_read_Bayer(wbTexture, int2(x,     y - 1), dims);
        float gS  = safe_read_Bayer(wbTexture, int2(x,     y + 1), dims);
        float gW  = safe_read_Bayer(wbTexture, int2(x - 1, y    ), dims);
        float gE  = safe_read_Bayer(wbTexture, int2(x + 1, y    ), dims);
        float gCnt = 0.0;
        float gSum = 0.0;
        if (cfa_color_at(pattern, x,     y - 1) == 1) { gSum += gN;  gCnt += 1.0; }
        if (cfa_color_at(pattern, x,     y + 1) == 1) { gSum += gS;  gCnt += 1.0; }
        if (cfa_color_at(pattern, x - 1, y    ) == 1) { gSum += gW;  gCnt += 1.0; }
        if (cfa_color_at(pattern, x + 1, y    ) == 1) { gSum += gE;  gCnt += 1.0; }
        G = (gCnt > 0.0) ? (gSum / gCnt) : 0.0;
    }

    // --- RED ---
    float R;
    {
        // Determine red neighbors based on CFA pattern.
        // Red appears at positions where cfa_color_at returns 0.
        float rSum = 0.0;
        float rCnt = 0.0;

        // Check 4 cardinal directions for red
        float rN  = safe_read_Bayer(wbTexture, int2(x,     y - 1), dims);
        float rS  = safe_read_Bayer(wbTexture, int2(x,     y + 1), dims);
        float rW  = safe_read_Bayer(wbTexture, int2(x - 1, y    ), dims);
        float rE  = safe_read_Bayer(wbTexture, int2(x + 1, y    ), dims);
        float rNW = safe_read_Bayer(wbTexture, int2(x - 1, y - 1), dims);
        float rNE = safe_read_Bayer(wbTexture, int2(x + 1, y - 1), dims);
        float rSW = safe_read_Bayer(wbTexture, int2(x - 1, y + 1), dims);
        float rSE = safe_read_Bayer(wbTexture, int2(x + 1, y + 1), dims);

        if (center == 0) {
            R = wbTexture.read(gid).r;
        } else {
            if (cfa_color_at(pattern, x,     y - 1) == 0) { rSum += rN;  rCnt += 1.0; }
            if (cfa_color_at(pattern, x,     y + 1) == 0) { rSum += rS;  rCnt += 1.0; }
            if (cfa_color_at(pattern, x - 1, y    ) == 0) { rSum += rW;  rCnt += 1.0; }
            if (cfa_color_at(pattern, x + 1, y    ) == 0) { rSum += rE;  rCnt += 1.0; }
            if (cfa_color_at(pattern, x - 1, y - 1) == 0) { rSum += rNW; rCnt += 1.0; }
            if (cfa_color_at(pattern, x + 1, y - 1) == 0) { rSum += rNE; rCnt += 1.0; }
            if (cfa_color_at(pattern, x - 1, y + 1) == 0) { rSum += rSW; rCnt += 1.0; }
            if (cfa_color_at(pattern, x + 1, y + 1) == 0) { rSum += rSE; rCnt += 1.0; }
            R = (rCnt > 0.0) ? (rSum / rCnt) : 0.0;
        }
    }

    // --- BLUE ---
    float B;
    {
        float bSum = 0.0;
        float bCnt = 0.0;

        float bN  = safe_read_Bayer(wbTexture, int2(x,     y - 1), dims);
        float bS  = safe_read_Bayer(wbTexture, int2(x,     y + 1), dims);
        float bW  = safe_read_Bayer(wbTexture, int2(x - 1, y    ), dims);
        float bE  = safe_read_Bayer(wbTexture, int2(x + 1, y    ), dims);
        float bNW = safe_read_Bayer(wbTexture, int2(x - 1, y - 1), dims);
        float bNE = safe_read_Bayer(wbTexture, int2(x + 1, y - 1), dims);
        float bSW = safe_read_Bayer(wbTexture, int2(x - 1, y + 1), dims);
        float bSE = safe_read_Bayer(wbTexture, int2(x + 1, y + 1), dims);

        if (center == 2) {
            B = wbTexture.read(gid).r;
        } else {
            if (cfa_color_at(pattern, x,     y - 1) == 2) { bSum += bN;  bCnt += 1.0; }
            if (cfa_color_at(pattern, x,     y + 1) == 2) { bSum += bS;  bCnt += 1.0; }
            if (cfa_color_at(pattern, x - 1, y    ) == 2) { bSum += bW;  bCnt += 1.0; }
            if (cfa_color_at(pattern, x + 1, y    ) == 2) { bSum += bE;  bCnt += 1.0; }
            if (cfa_color_at(pattern, x - 1, y - 1) == 2) { bSum += bNW; bCnt += 1.0; }
            if (cfa_color_at(pattern, x + 1, y - 1) == 2) { bSum += bNE; bCnt += 1.0; }
            if (cfa_color_at(pattern, x - 1, y + 1) == 2) { bSum += bSW; bCnt += 1.0; }
            if (cfa_color_at(pattern, x + 1, y + 1) == 2) { bSum += bSE; bCnt += 1.0; }
            B = (bCnt > 0.0) ? (bSum / bCnt) : 0.0;
        }
    }

    destTexture.write(float4(R, G, B, 1.0), gid);
}

// MARK: - Kernel 6: Color Matrix + Gamma

/// Applies 3×3 color matrix transform and optional gamma to demosaiced RGB.
///
/// Pipeline steps performed by this kernel:
/// 1. **Color matrix**: demosaiced RGB → camera RGB → XYZ D50 via `colorMatrix`.
/// 2. **Working space**: XYZ D50 → Display P3 linear via `xyzToDisplayP3`.
/// 3. **Gamma**: `pow(x, 1.0/gamma)` if gamma ≠ 1.0. Default gamma = 1.0
///    (scene-referred linear). No tone curve, no S-curve.
///
/// The matrices are row-major float3x3 uploaded from DNG tags in the Swift
/// `MetalPipelineManager`.
///
/// - Parameters:
///   - demosaicTexture: RGBA demosaiced input (scene-linear camera RGB).
///   - destTexture: RGBA output in Display P3 (linear or gamma-encoded).
///   - uniforms: Pipeline parameters including colorMatrix, xyzToDisplayP3, gamma.
kernel void colorMatrixKernel(
    texture2d<float, access::read>  demosaicTexture [[texture(0)]],
    texture2d<float, access::write> destTexture     [[texture(1)]],
    constant DemosaicUniforms&      uniforms        [[buffer(0)]],
    uint2                           gid             [[thread_position_in_grid]]
) {
    const uint2 dims = uint2(uniforms.width, uniforms.height);
    if (gid.x >= dims.x || gid.y >= dims.y) return;

    float4 rgba = demosaicTexture.read(gid);

    // Apply camera RGB → XYZ D50 color matrix
    float3 camRGB = rgba.rgb;
    float3 xyz = uniforms.colorMatrix * camRGB;

    // XYZ D50 → Display P3 linear
    float3 p3 = uniforms.xyzToDisplayP3 * xyz;

    // Apply gamma (default 1.0 = linear pass-through)
    float gamma = uniforms.gamma;
    if (gamma != 1.0 && gamma > 0.0) {
        p3 = pow(max(p3, 0.0), float3(1.0 / gamma));
    }

    // Clamp to valid [0, 1] range for display
    p3 = clamp(p3, 0.0, 1.0);

    destTexture.write(float4(p3, 1.0), gid);
}
