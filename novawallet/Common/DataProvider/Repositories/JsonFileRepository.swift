import Foundation
import RobinHood

class JsonFileRepository<Model> where Model: Decodable {
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder = .init()) {
        self.decoder = decoder
    }

    func fetchOperationWrapper(by url: URL?, defaultValue: Model) -> CompoundOperationWrapper<Model> {
        CompoundOperationWrapper(targetOperation: fetchOperation(by: url, defaultValue: defaultValue))
    }

    func fetchOperation(by url: URL?, defaultValue: Model) -> BaseOperation<Model> {
        let fetchOperation = ClosureOperation<Model> { [weak self] in
            guard let self = self, let jsonUrl = url else {
                return defaultValue
            }

            let data = try Data(contentsOf: jsonUrl)

            return try self.decoder.decode(Model.self, from: data)
        }

        return fetchOperation
    }
}
