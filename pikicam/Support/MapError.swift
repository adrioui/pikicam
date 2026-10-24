// periphery:ignore
import Foundation

func mapError<A, E: Error, F: Error>(
    _ transform: @escaping (F) -> E,
    _ operation: @escaping () async throws(F) -> A
) async throws(E) -> A {
    do {
        return try await operation()
    } catch {
        throw transform(error)
    }
}
