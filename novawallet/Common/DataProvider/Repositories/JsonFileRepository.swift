import Foundation
import RobinHood

class JsonFileRepository<Model> where Model: Decodable {
    func fetchOperationWrapper(by url: URL?, defaultValue: Model) -> CompoundOperationWrapper<Model> {
        CompoundOperationWrapper(targetOperation: fetchOperation(by: url, defaultValue: defaultValue))
    }

    func fetchOperation(by url: URL?, defaultValue: Model) -> BaseOperation<Model> {
        let fetchOperation = ClosureOperation<Model> {
            guard let jsonUrl = url else {
                return defaultValue
            }

            let data = try Data(contentsOf: jsonUrl)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Model.self, from: data)
        }

        return fetchOperation
    }
}

extension JsonFileRepository {
    func fetchAndMapOperation<Result>(
        by url: URL?,
        defaultValue: Model,
        mapper: @escaping (Model) -> Result
    ) -> CompoundOperationWrapper<Result> {
        let fetchOperation = fetchOperation(by: url, defaultValue: defaultValue)
        let mapOperation = ClosureOperation {
            let result = try fetchOperation.extractNoCancellableResultData()
            return mapper(result)
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
