import Foundation

func dispatchInQueueWhenPossible(_ queue: DispatchQueue?, block: @escaping () -> Void) {
    if let queue = queue {
        queue.async(execute: block)
    } else {
        block()
    }
}

func callbackClosureIfProvided<T>(
    _ closure: ((Result<T, Error>) -> Void)?,
    queue: DispatchQueue?,
    result: Result<T, Error>
) {
    guard let closure = closure else {
        return
    }

    dispatchInQueueWhenPossible(queue) {
        closure(result)
    }
}

func dispatchInConcurrent(queue: DispatchQueue, locking mutex: NSLock, block: @escaping () -> Void) {
    queue.async {
        mutex.lock()

        block()

        mutex.unlock()
    }
}
