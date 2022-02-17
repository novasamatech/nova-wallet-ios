import Foundation
import RobinHood
import SubstrateSdk

enum StorageKeyDecodingError: Error {
    case missingCoderFactory
    case missingDataList
    case invalidStoragePath
    case incompatibleHasher
}

final class StorageKeyDecodingOperation<T: Decodable>: BaseOperation<[T]> {
    let path: StorageCodingPath

    var codingFactory: RuntimeCoderFactoryProtocol?
    var dataList: [Data]?

    init(
        path: StorageCodingPath,
        codingFactory: RuntimeCoderFactoryProtocol? = nil,
        dataList: [Data]? = nil
    ) {
        self.path = path
        self.codingFactory = codingFactory
        self.dataList = dataList
    }

    private func extractKeys(
        from data: Data,
        keyTypes: [String],
        hashers: [StorageHasher],
        codingFactory: RuntimeProviderFactoryProtocol
    ) throws -> [JSON] {
        let decoder = try codingFactory.createDecoder(from: data)

        let values: [JSON] = zip(keyTypes, hashers).reduce(([JSON](), decoder)) { (result, item) in
            switch hasher {
            case .blake128:
                _ = decoder.readBytes(length: 16)
                return nil
            case .blake256:
                _ = decoder.readBytes(length: 32)
                return nil
            case .blake128Concat:
                _ = decoder.readBytes(length: 16)
                return decoder.read(type: keyType)
            case .twox128:
                _ = decoder.readBytes(length: 16)
                return nil
            case .twox256:
                _ = decoder.readBytes(length: 32)
                return nil
            case .twox64Concat:
                _ = decoder.readBytes(length: 8)
                return decoder.read(type: keyType)
            case .identity:
                return decoder.read(type: keyType)
            }
        }
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard let factory = codingFactory else {
                throw StorageKeyDecodingError.missingCoderFactory
            }

            guard let dataList = dataList else {
                throw StorageKeyDecodingError.missingDataList
            }

            guard let entry = factory.metadata.getStorageMetadata(
                in: path.moduleName,
                storageName: path.itemName
            ) else {
                throw StorageKeyEncodingOperationError.invalidStoragePath
            }

            switch entry.type {
            case let .map(entry):
                break
            case let .doubleMap(entry):
                break
            case let .nMap(entry):
                break
            case .plain:
                break
            }

            result = .success([])
        } catch {
            result = .failure(error)
        }
    }
}
