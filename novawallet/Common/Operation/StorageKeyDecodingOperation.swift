import Foundation
import RobinHood
import SubstrateSdk

enum StorageKeyDecodingError: Error {
    case missingCoderFactory
    case missingDataList
    case invalidStoragePath
    case incompatibleHasher
}

final class StorageKeyDecodingOperation<T: JSONListConvertible>: BaseOperation<[T]> {
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
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> T {
        let decoder = try codingFactory.createDecoder(from: data)

        var values = [JSON]()

        for (keyType, hasher) in zip(keyTypes, hashers) {
            switch hasher {
            case .blake128:
                _ = try decoder.readBytes(length: 16)
            case .blake256:
                _ = try decoder.readBytes(length: 32)
            case .blake128Concat:
                _ = try decoder.readBytes(length: 16)
                let value = try decoder.read(type: keyType)
                values.append(value)
            case .twox128:
                _ = try decoder.readBytes(length: 16)
            case .twox256:
                _ = try decoder.readBytes(length: 32)
            case .twox64Concat:
                _ = try decoder.readBytes(length: 8)
                let value = try decoder.read(type: keyType)
                values.append(value)
            case .identity:
                let value = try decoder.read(type: keyType)
                values.append(value)
            }
        }

        let context = codingFactory.createRuntimeJsonContext()
        return try T(jsonList: values, context: context.toRawContext())
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

            let models: [T] = try dataList.map { data in
                switch entry.type {
                case let .map(entry):
                    return try extractKeys(
                        from: data,
                        keyTypes: [entry.key],
                        hashers: [entry.hasher],
                        codingFactory: factory
                    )
                case let .doubleMap(entry):
                    return try extractKeys(
                        from: data,
                        keyTypes: [entry.key1, entry.key2],
                        hashers: [entry.hasher, entry.key2Hasher],
                        codingFactory: factory
                    )
                case let .nMap(entry):
                    return try extractKeys(
                        from: data,
                        keyTypes: entry.keyVec,
                        hashers: entry.hashers,
                        codingFactory: factory
                    )
                case .plain:
                    return try T(jsonList: [], context: nil)
                }
            }

            result = .success(models)
        } catch {
            result = .failure(error)
        }
    }
}
