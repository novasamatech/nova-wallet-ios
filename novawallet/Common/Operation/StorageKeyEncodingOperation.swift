import Foundation
import SubstrateSdk
import Operation_iOS

enum StorageKeyEncodingOperationError: Error {
    case missingRequiredParams
    case incompatibleStorageType
    case invalidStoragePath
}

class UnkeyedEncodingOperation: BaseOperation<Data> {
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(path: StorageCodingPath, storageKeyFactory: StorageKeyFactoryProtocol) {
        self.path = path
        self.storageKeyFactory = storageKeyFactory

        super.init()
    }

    override func performAsync(_ callback: @escaping (Result<Data, Error>) -> Void) throws {
        guard let factory = codingFactory else {
            throw StorageKeyEncodingOperationError.missingRequiredParams
        }

        guard factory.metadata.getStorageMetadata(in: path.moduleName, storageName: path.itemName) != nil else {
            throw StorageKeyEncodingOperationError.invalidStoragePath
        }

        let keyData: Data = try storageKeyFactory.createStorageKey(
            moduleName: path.moduleName,
            storageName: path.itemName
        )

        callback(.success(keyData))
    }
}

class MapKeyEncodingOperation<T: Encodable>: BaseOperation<[Data]> {
    var keyParams: [T]?
    var codingFactory: RuntimeCoderFactoryProtocol?
    var paramEncoder: ((T) throws -> Data)?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams: [T]? = nil,
        paramEncoder: ((T) throws -> Data)? = nil
    ) {
        self.path = path
        self.keyParams = keyParams
        self.storageKeyFactory = storageKeyFactory
        self.paramEncoder = paramEncoder

        super.init()
    }

    override func performAsync(_ callback: @escaping (Result<[Data], Error>) -> Void) throws {
        guard let factory = codingFactory, let keyParams = keyParams else {
            throw StorageKeyEncodingOperationError.missingRequiredParams
        }

        guard let entry = factory.metadata.getStorageMetadata(
            in: path.moduleName,
            storageName: path.itemName
        ) else {
            throw StorageKeyEncodingOperationError.invalidStoragePath
        }

        let keyType: String
        let hasher: StorageHasher

        switch entry.type {
        case let .map(mapEntry):
            keyType = mapEntry.key
            hasher = mapEntry.hasher
        case let .doubleMap(doubleMapEntry):
            keyType = doubleMapEntry.key1
            hasher = doubleMapEntry.hasher
        case let .nMap(nMapEntry):
            guard
                let firstKey = nMapEntry.keyVec.first,
                let firstHasher = nMapEntry.hashers.first else {
                throw StorageKeyEncodingOperationError.missingRequiredParams
            }

            keyType = firstKey
            hasher = firstHasher
        case .plain:
            throw StorageKeyEncodingOperationError.incompatibleStorageType
        }

        let keys: [Data] = try keyParams.map { keyParam in
            let encodedParam: Data

            if let paramEncoder = paramEncoder {
                encodedParam = try paramEncoder(keyParam)
            } else {
                encodedParam = try encodeParam(
                    keyParam,
                    factory: factory,
                    type: keyType
                )
            }

            return try storageKeyFactory.createStorageKey(
                moduleName: path.moduleName,
                storageName: path.itemName,
                key: encodedParam,
                hasher: hasher
            )
        }

        callback(.success(keys))
    }

    private func encodeParam<P: Encodable>(
        _ param: P,
        factory: RuntimeCoderFactoryProtocol,
        type: String
    ) throws -> Data {
        let encoder = factory.createEncoder()
        try encoder.append(param, ofType: type)
        return try encoder.encode()
    }
}

class DoubleMapKeyEncodingOperation<T1: Encodable, T2: Encodable>: BaseOperation<[Data]> {
    var keyParams1: [T1]?
    var keyParams2: [T2]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath
    let storageKeyFactory: StorageKeyFactoryProtocol

    var param1Encoder: ((T1) throws -> Data)?
    var param2Encoder: ((T2) throws -> Data)?

    init(
        path: StorageCodingPath,
        storageKeyFactory: StorageKeyFactoryProtocol,
        keyParams1: [T1]? = nil,
        keyParams2: [T2]? = nil,
        param1Encoder: ((T1) throws -> Data)? = nil,
        param2Encoder: ((T2) throws -> Data)? = nil
    ) {
        self.path = path
        self.keyParams1 = keyParams1
        self.keyParams2 = keyParams2
        self.storageKeyFactory = storageKeyFactory
        self.param1Encoder = param1Encoder
        self.param2Encoder = param2Encoder

        super.init()
    }

    override func performAsync(_ callback: @escaping (Result<[Data], Error>) -> Void) throws {
        guard let factory = codingFactory,
              let keyParams1 = keyParams1,
              let keyParams2 = keyParams2,
              keyParams1.count == keyParams2.count
        else {
            throw StorageKeyEncodingOperationError.missingRequiredParams
        }

        guard let entry = factory.metadata.getStorageMetadata(
            in: path.moduleName,
            storageName: path.itemName
        ) else {
            throw StorageKeyEncodingOperationError.invalidStoragePath
        }

        guard case let .doubleMap(doubleMapEntry) = entry.type else {
            throw StorageKeyEncodingOperationError.incompatibleStorageType
        }

        let keys: [Data] = try zip(keyParams1, keyParams2).map { param in
            let encodedParam1: Data

            if let param1Encoder = param1Encoder {
                encodedParam1 = try param1Encoder(param.0)
            } else {
                encodedParam1 = try encodeParam(
                    param.0,
                    factory: factory,
                    type: doubleMapEntry.key1
                )
            }

            let encodedParam2: Data

            if let param2Encoder = param2Encoder {
                encodedParam2 = try param2Encoder(param.1)
            } else {
                encodedParam2 = try encodeParam(
                    param.1,
                    factory: factory,
                    type: doubleMapEntry.key2
                )
            }

            return try storageKeyFactory.createStorageKey(
                moduleName: path.moduleName,
                storageName: path.itemName,
                key1: encodedParam1,
                hasher1: doubleMapEntry.hasher,
                key2: encodedParam2,
                hasher2: doubleMapEntry.key2Hasher
            )
        }

        callback(.success(keys))
    }

    private func encodeParam<T: Encodable>(
        _ param: T,
        factory: RuntimeCoderFactoryProtocol,
        type: String
    ) throws -> Data {
        let encoder = factory.createEncoder()
        try encoder.append(param, ofType: type)
        return try encoder.encode()
    }
}
