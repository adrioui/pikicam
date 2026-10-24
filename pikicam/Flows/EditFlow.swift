import Foundation

struct EditFlow: Sendable {
    let deps: Dependencies

    func commit(_ item: LibraryItem, look: LookParameters, geometry: FrameGeometry) async throws(ViewerError) {
        let dng: Data
        do {
            dng = try await deps.library.dng(for: item.id)
        } catch {
            throw ViewerError.library(error)
        }
        let rendition: Rendition?
        do {
            rendition = try await deps.developer.export(dng, look: look, geometry: geometry)
        } catch {
            throw ViewerError.develop(error)
        }
        let payload = AdjustmentPayload(
            look: look, geometry: geometry,
            recipeVersion: NeutralRecipe.version,
            decoderVersion: look.decoderVersion,
            provenance: nil
        )
        do {
            try await deps.library.commitEdit(item.id, payload: payload, rendition: rendition)
        } catch {
            throw ViewerError.library(error)
        }
    }
}
