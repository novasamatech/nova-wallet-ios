import Foundation
import Operation_iOS
import SubstrateSdk

protocol NMapKeyStorageKeyProtocol {
    func appendSubkey(
        to encoder: DynamicScaleEncoding,
        type: String,
        index: Int
    ) throws
}

final class NMapKeyEncodingOperation: BaseOperation<[Data]> {
    var keys: [NMapKeyStorageKeyProtocol]?

    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keys: [NMapKeyStorageKeyProtocol]? = nil
    ) {
        self.path = path
        self.keys = keys
        self.storageKeyFactory = storageKeyFactory

        super.init()
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
            guard let factory = codingFactory, let keys = keys else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(
                in: path.moduleName,
                storageName: path.itemName
            ) else {
                throw StorageKeyEncodingOperationError.invalidStoragePath
            }

            guard case let .nMap(nMapEntry) = entry.type else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            let encodedKeys: [Data] = try keys.map { key in
                let initRawKey = try storageKeyFactory.createStorageKey(
                    moduleName: path.moduleName,
                    storageName: path.itemName
                )

                let paramsCount = nMapEntry.hashers.count
                let encodedKey = try Array(0 ..< paramsCount).reduce(initRawKey) { partialKey, index in
                    let paramType = nMapEntry.keyVec[index]
                    let hasher = nMapEntry.hashers[index]

                    let encoder = factory.createEncoder()
                    try key.appendSubkey(
                        to: encoder,
                        type: paramType,
                        index: index
                    )

                    let encodedParam = try encoder.encode()

                    let subkey = try hasher.hash(data: encodedParam)

                    return partialKey + subkey
                }

                return encodedKey
            }

            result = .success(encodedKeys)
        } catch {
            result = .failure(error)
        }
    }
}
