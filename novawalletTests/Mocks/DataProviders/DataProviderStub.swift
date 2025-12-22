import Foundation
import Operation_iOS
@testable import novawallet

final class DataProviderStub<T: Identifiable>: DataProviderProtocol {
    typealias Model = T

    let models: [T]

    let executionQueue = OperationQueue()

    init(models: [T]) {
        self.models = models
    }

    func fetch(
        by modelId: String,
        completionBlock _: ((Result<Model?, Error>?) -> Void)?
    ) -> CompoundOperationWrapper<Model?> {
        let model = models.first(where: { $0.identifier == modelId })
        return CompoundOperationWrapper.createWithResult(model)
    }

    func fetch(
        page _: UInt,
        completionBlock _: ((Result<[Model], Error>?) -> Void)?
    ) -> CompoundOperationWrapper<[Model]> {
        CompoundOperationWrapper.createWithResult(models)
    }

    func addObserver(
        _: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<Model>]) -> Void,
        failing _: @escaping (Error) -> Void,
        options _: DataProviderObserverOptions
    ) {
        let changes = models.map { DataProviderChange.insert(newItem: $0) }
        dispatchInQueueWhenPossible(queue) {
            updateBlock(changes)
        }
    }

    func removeObserver(_: AnyObject) {}

    func refresh() {}
}
