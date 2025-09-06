import Foundation
import Operation_iOS
@testable import novawallet

final class DataProviderRepositoryStub<T: Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T

    @Atomic(defaultValue: []) var models: [T]

    init(models: [T]) {
        self.models = models
    }

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<Model?> {
        ClosureOperation { [weak self] in
            let identifier = try modelIdClosure()

            return self?.models.first(where: { $0.identifier == identifier })
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        BaseOperation.createWithResult(models)
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[Model]> {
        ClosureOperation {
            self.models
        }
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [Model],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation {
            let updatedModels = try updateModelsBlock()

            var deletingIds = Set(try deleteIdsBlock())

            for updatedModel in updatedModels {
                deletingIds.insert(updatedModel.identifier)
            }

            let newModels = self.models.filter { !deletingIds.contains($0.identifier) }

            self.models = newModels + updatedModels
        }
    }

    func replaceOperation(_ newModelsBlock: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation {
            self.models = try newModelsBlock()
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation {
            self.models.count
        }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {
            self.models = []
        }
    }
}

final class DataProviderObservableStub<T>: DataProviderRepositoryObservable {
    typealias Model = T

    func start(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func stop(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func addObserver(
        _: AnyObject,
        deliverOn _: DispatchQueue,
        executing _: @escaping ([DataProviderChange<Model>]) -> Void
    ) {}

    func removeObserver(_: AnyObject) {}
}
