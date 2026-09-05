import Foundation

public enum KXSFRetry {
    public static func run<Value: Sendable>(
        maxAttempts: Int,
        delay: @escaping @Sendable (_ failedAttempt: Int) async throws -> Void,
        operation: @escaping @Sendable (_ attempt: Int) async throws -> Value
    ) async throws -> Value {
        precondition(maxAttempts > 0, "Retry attempts must be positive")

        for attempt in 1...maxAttempts {
            do {
                return try await operation(attempt)
            } catch {
                guard attempt < maxAttempts else { throw error }
                try await delay(attempt)
            }
        }

        preconditionFailure("A positive retry count always returns or throws")
    }
}
