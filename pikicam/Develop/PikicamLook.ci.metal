#include <CoreImage/CoreImage.h>
#include <metal_stdlib>
using namespace metal;

namespace piki {

constant float3 P3_LUMA = float3(0.22897, 0.69174, 0.07929);

float filmicCurve(float x, float contrast, float highlights, float shadows) {
    float toe = 0.06;
    float shoulderInput = 2.69;
    float compressed = x / (x + toe);
    float shoulder = shoulderInput / (shoulderInput + toe);
    float normalized = compressed / shoulder;
    normalized = pow(clamp(normalized, 1e-6, 100.0), 1.0 - contrast * 0.35);
    float shadowWeight = exp2(-normalized * 8.0);
    float highlightWeight = exp2(-(1.0 - normalized) * 6.0);
    normalized = normalized + shadows * 0.18 * shadowWeight - highlights * 0.18 * highlightWeight;
    return clamp(normalized, 0.0, 1.0);
}

float3 gamutCompress(float3 rgb, float threshold, float limit) {
    float achromatic = max(rgb.r, max(rgb.g, rgb.b));
    if (achromatic <= 0.0) {
        return rgb;
    }
    float3 direction = rgb / achromatic;
    float distance = length(direction - float3(1.0));
    if (distance <= threshold) {
        return rgb;
    }
    float compressed = (distance - threshold) / (limit - threshold);
    compressed = compressed / (1.0 + compressed);
    float target = threshold + compressed * (limit - threshold);
    float3 offset = direction - float3(1.0);
    float3 compressedOffset = normalize(offset) * target;
    return (float3(1.0) + compressedOffset) * achromatic;
}

float dither(uint2 pixel, float lsb) {
    uint hash = pixel.x * 1973u + pixel.y * 9277u + 26699u;
    hash = (hash ^ (hash >> 13u)) * 1274126177u;
    hash = hash ^ (hash >> 16u);
    float unit = float(hash & 0xFFFFu) / 65535.0;
    return (unit - 0.5) * lsb;
}

}

extern "C" {
    namespace coreimage {

        float4 pikicamLook(sampler src, float exposureEV, float3 monoWeights, float monoActive, float contrast, float highlights, float shadows, float ditherLSB) {
            float2 coordinates = src.coord();
            float4 pixel = src.sample(coordinates);
            float3 rgb = max(pixel.rgb, 0.0);
            rgb *= exp2(exposureEV);
            if (monoActive > 0.5) {
                rgb = float3(dot(rgb, monoWeights));
            }
            float3 mapped;
            mapped.r = piki::filmicCurve(rgb.r, contrast, highlights, shadows);
            mapped.g = piki::filmicCurve(rgb.g, contrast, highlights, shadows);
            mapped.b = piki::filmicCurve(rgb.b, contrast, highlights, shadows);
            mapped = piki::gamutCompress(mapped, 0.02, 0.35);
            mapped += piki::dither(uint2(coordinates * 4096.0), ditherLSB);
            return float4(clamp(mapped, 0.0, 1.0), pixel.a);
        }

    }
}
