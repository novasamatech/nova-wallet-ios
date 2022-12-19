import RobinHood

final class EmptyDataProviderRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        BaseOperation.createWithResult([])
    }

    typealias Model = T

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<T?> {
        BaseOperation.createWithResult(nil)
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        BaseOperation.createWithResult([])
    }

    func saveOperation(_: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func replaceOperation(_: @escaping () throws -> [T]) -> RobinHood.BaseOperation<Void> {
        ClosureOperation {}
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        BaseOperation.createWithResult(0)
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {}
    }
}
