import Foundation
import RobinHood

protocol RMRKV1NftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV1]>
    func fetchCollection(for identifier: String) -> BaseOperation<[RMRKV1Collection]>
}

final class RMRKV1OperationFactory: BaseFetchOperationFactory {
    static let accountPath = "/account"
    static let collectionPath = "/collection"
    static let baseURL = URL(string: "https://singular.rmrk.app/api/rmrk1")!
}

extension RMRKV1OperationFactory: RMRKV1NftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV1]> {
        let url = Self.baseURL.appendingPathComponent(Self.accountPath).appendingPathComponent(address)
        return createFetchOperation(from: url, shouldUseCache: false)
    }

    func fetchCollection(for identifier: String) -> BaseOperation<[RMRKV1Collection]> {
        let url = Self.baseURL.appendingPathComponent(Self.collectionPath).appendingPathComponent(identifier)
        return createFetchOperation(from: url, shouldUseCache: false)
    }
}
