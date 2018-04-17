
import PromisesCore

let queue = DispatchQueue(label: #function, qos: .userInitiated)
let otherThread = DispatchQueue.global(qos: .background)
let semaphore = DispatchSemaphore(value: 0)

struct Constants {
    static let iterationCount = 20_000
}

func print(average time: Double) {
    print(String(format: "Average time: %.10lf", Double(time) / Double(Constants.iterationCount)))
}

var time: Double = 0

func bench() {
    Promise<Void>((), on: queue)
        .map {
            ()
//            Promise { r in
//                otherThread.async {
//                    r.fulfill(())
//                }
//            }
        }
        .map { ()
//            Promise { r in
//                otherThread.async {
//                    r.fulfill(())
//                }
//            }
        }
        .done {
            semaphore.signal()
    }

    semaphore.wait()
}
// Act.
func measureTime(_ block: () -> Void) -> Double {
    let start = Date()
    block()
    return Date().timeIntervalSince(start)
}

DispatchQueue.main.async {
    time = (0 ..< Constants.iterationCount).reduce(0) { current, _ in
        current + measureTime(bench)
    }
}

// Assert.
RunLoop.main.run(until: Date().addingTimeInterval(5))
print(average: time)
