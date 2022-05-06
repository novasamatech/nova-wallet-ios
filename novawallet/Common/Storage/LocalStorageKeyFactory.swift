import Foundation
import SubstrateSdk

enum LocalStorageKeyFactoryError: Error {
    case invalidParams
}

protocol LocalStorageKeyFactoryProtocol {
    func createKey(from remoteKey: Data, chainId: ChainModel.Id) throws -> String
    func createRestorableKey(from remoteKey: Data, chainId: ChainModel.Id) throws -> String
    func restoreRemoteKey(from localKey: String, chainId: ChainModel.Id) throws -> Data
}

extension LocalStorageKeyFactoryProtocol {
    func createFromStoragePath(_ storagePath: StorageCodingPath, chainId: ChainModel.Id) throws -> String {
        let data = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        return try createKey(from: data, chainId: chainId)
    }

    func createFromStoragePath(
        _ storagePath: StorageCodingPath,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> String {
        let data = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        return try createKey(from: data + accountId, chainId: chainId)
    }

    func createFromStoragePath(
        _ storagePath: StorageCodingPath,
        encodableElement: ScaleEncodable,
        chainId: ChainModel.Id
    ) throws -> String {
        let storagePathData = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        let elementData = try encodableElement.scaleEncoded()

        return try createKey(from: storagePathData + elementData, chainId: chainId)
    }

    func createFromStoragePath(
        _ storagePath: StorageCodingPath,
        encodableElements: [ScaleEncodable],
        chainId: ChainModel.Id
    ) throws -> String {
        let storagePathData = try StorageKeyFactory().createStorageKey(
            moduleName: storagePath.moduleName,
            storageName: storagePath.itemName
        )

        let data = try encodableElements.reduce(Data()) { result, element in
            let scaleData = try element.scaleEncoded()
            return result + scaleData
        }

        return try createKey(from: storagePathData + data, chainId: chainId)
    }
}

final class LocalStorageKeyFactory: LocalStorageKeyFactoryProtocol {
    func createKey(from remoteKey: Data, chainId: ChainModel.Id) throws -> String {
        let concatData = (try Data(hexString: chainId)) + remoteKey
        let localKey = try StorageHasher.twox256.hash(data: concatData)
        return localKey.toHex()
    }

    func createRestorableKey(from remoteKey: Data, chainId: ChainModel.Id) throws -> String {
        let chainIdData = try Data(hexString: chainId)

        return (chainIdData + remoteKey).toHex()
    }

    func restoreRemoteKey(from localKey: String, chainId: ChainModel.Id) throws -> Data {
        let chainIdData = try Data(hexString: chainId)
        let fullKey = try Data(hexString: localKey)

        return fullKey.suffix(fullKey.count - chainIdData.count)
    }
}
