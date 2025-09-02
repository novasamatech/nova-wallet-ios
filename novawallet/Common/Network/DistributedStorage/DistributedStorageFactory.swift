import Foundation
import Operation_iOS

protocol DistributedStorageOperationFactoryProtocol {
    func createOperation<T: Decodable>(for storage: DistributedStorage) -> BaseOperation<T>
}

final class DistributedStorageOperationFactory: BaseFetchOperationFactory {
    static let ipfsBaseUrl = URL(string: "https://image.w.kodadot.xyz/ipfs")!

    static func resolveUrl(from storage: DistributedStorage) -> URL {
        switch storage {
        case let .ipfs(path):
            return Self.ipfsBaseUrl.appendingPathComponent(path)
        }
    }
}

extension DistributedStorageOperationFactory: DistributedStorageOperationFactoryProtocol {
    func createOperation<T>(for storage: DistributedStorage) -> BaseOperation<T> where T: Decodable {
        let url = Self.resolveUrl(from: storage)
        return createFetchOperation(from: url)
    }
}
