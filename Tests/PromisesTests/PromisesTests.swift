import XCTest
@testable import PromisesCore

final class PromisesTests: XCTestCase {

    static var allTests = [
        ("testTripleThenOnSerialQueue", testTripleThenOnSerialQueue),
    ]

    func testTripleThenOnSerialQueue() {
        // Arrange.
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = Constants.iterationCount
        let queue = DispatchQueue(label: #function, qos: .userInitiated)
        let otherThread = DispatchQueue.global(qos: .background)
        let semaphore = DispatchSemaphore(value: 0)

        // Act.
        DispatchQueue.main.async {
            let time = dispatch_benchmark(Constants.iterationCount) {
                Promise<Void>(value: ())
                    .bind(to: queue)
                    .then {
                        Promise { r in
                            otherThread.async {
                                r.fulfill(())
                            }
                        }
                    }
                    .then {
                        Promise { r in
                            otherThread.async {
                                r.fulfill(())
                            }
                        }
                    }
                    .done {
                        semaphore.signal()
                        expectation.fulfill()
                    }

                semaphore.wait()
            }
            print(average: time)
        }

        // Assert.
        waitForExpectations(timeout: 10)
    }
}

struct Constants {
    static let iterationCount = 10_000
}

func print(average time: UInt64) {
    print(String(format: "Average time: %.10lf", Double(time) / Double(NSEC_PER_SEC)))
}
