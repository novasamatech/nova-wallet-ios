import Foundation
import Operation_iOS

class LongrunOperation<T>: BaseOperation<T> {
    let longrun: AnyLongrun<T>

    init(longrun: AnyLongrun<T>) {
        self.longrun = longrun
    }

    override func performAsync(_ callback: @escaping (Result<T, Error>) -> Void) throws {
        longrun.start(with: callback)
    }

    override func cancel() {
        longrun.cancel()

        super.cancel()
    }
}
