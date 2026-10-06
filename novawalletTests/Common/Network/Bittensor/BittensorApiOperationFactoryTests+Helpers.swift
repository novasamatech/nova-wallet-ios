import Foundation

extension BittensorApiOperationFactoryTests {
    final class ReplyLatch {
        private let lock = NSLock()
        private var isReleased = false
        private var heldReplies: [() -> Void] = []

        func hold(_ reply: @escaping () -> Void) {
            lock.lock()

            guard !isReleased else {
                lock.unlock()
                reply()
                return
            }

            heldReplies.append(reply)
            lock.unlock()
        }

        func release() {
            lock.lock()
            isReleased = true
            let replies = heldReplies
            heldReplies = []
            lock.unlock()

            replies.forEach { $0() }
        }
    }

    final class ManualClock {
        private let lock = NSLock()
        private var value: TimeInterval = 1000

        var now: TimeInterval {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func advance(by interval: TimeInterval) {
            lock.lock()
            value += interval
            lock.unlock()
        }
    }
}
