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

            return try JSONDecoder().decode(Model.self, from: data)
        }

        return fetchOperation
    }
}
