import Foundation
import Operation_iOS
@testable import novawallet

final class SingleValueProviderStub<T>: SingleValueProviderProtocol {
    typealias Model = T

    let item: T?

    let executionQueue = OperationQueue()

    init(item: T?) {
        self.item = item
    }

    func fetch(with _: ((Result<Model?, Error>?) -> Void)?) -> CompoundOperationWrapper<Model?> {
        CompoundOperationWrapper.createWithResult(item)
    }

    func addObserver(
        _: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing _: @escaping (Error) -> Void,
        options _: DataProviderObserverOptions
    ) {
        let changes: [DataProviderChange<T>]

        if let item = item {
            changes = [DataProviderChange.insert(newItem: item)]
        } else {
            changes = []
        }

        dispatchInQueueWhenPossible(queue) {
            updateBlock(changes)
        }
    }

    func removeObserver(_: AnyObject) {}

    func refresh() {}
}
