import Foundation

protocol StorageKeyDecodingProtocol: JSONListConvertible {
    static func decodeStorageKey(
        from data: Data,
        path: StorageCodingPath,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> Self
}

extension StorageKeyDecodingProtocol {
    static func decodeStorageKey(
        from data: Data,
        path: StorageCodingPath,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> Self {
        let operation = StorageKeyDecodingOperation<Self>(
            path: path,
            codingFactory: coderFactory,
            dataList: [data]
        )

        operation.start()

        guard let result = try operation.extractNoCancellableResultData().first else {
            throw CommonError.dataCorruption
        }

        return result
    }
}
