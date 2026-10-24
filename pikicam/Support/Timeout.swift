// periphery:ignore
import Foundation

enum TimeoutOutcome<A: Sendable, E: Error> {
    case value(A)
    case failure(E)
    case timedOut
}

func withTimeout<E: Error, A: Sendable>(
    _ duration: Duration,
    clock: any Clock<Duration>,
    onTimeout: @escaping @Sendable () -> E,
    _ operation: @escaping @Sendable () async throws(E) -> A
) async throws(E) -> A {
    let outcome: TimeoutOutcome<A, E> = await withTaskGroup(of: TimeoutOutcome<A, E>.self) { group in
        group.addTask {
            do {
                return .value(try await operation())
            } catch let error as E {
                return .failure(error)
            } catch {
                preconditionFailure("operation declared throws(E) — untyped escape is an invariant violation")
            }
        }
        group.addTask {
            try? await clock.sleep(for: duration)
            return .timedOut
        }
        let first = await group.next() ?? .timedOut
        group.cancelAll()
        return first
    }
    switch outcome {
    case .value(let value):
        return value
    case .failure(let error):
        throw error
    case .timedOut:
        throw onTimeout()
    }
}
