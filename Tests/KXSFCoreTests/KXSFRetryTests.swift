import XCTest
@testable import KXSFCore

final class KXSFRetryTests: XCTestCase {
    func test_retries_transient_failure_until_third_attempt_succeeds() async throws {
        let counter = AttemptCounter()

        let value = try await KXSFRetry.run(
            maxAttempts: 3,
            delay: { _ in }
        ) { _ in
            let attempt = await counter.increment()
            if attempt < 3 {
                throw TestFailure.transient
            }
            return "loaded"
        }

        let attempts = await counter.value
        XCTAssertEqual(value, "loaded")
        XCTAssertEqual(attempts, 3)
    }
}

private actor AttemptCounter {
    private(set) var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

private enum TestFailure: Error {
    case transient
}
