import Foundation
import RobinHood

protocol RMRKV2NftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV2]>
    func fetchCollection(for identifier: String) -> BaseOperation<[RMRKV2Collection]>
}

final class RMRKV2OperationFactory: BaseFetchOperationFactory {
    static let accountPath = "/account"
    static let collectionPath = "/collection"
    static let baseURL = URL(string: "https://kanaria.rmrk.app/api/rmrk2")!
}

extension RMRKV2OperationFactory: RMRKV2NftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV2]> {
        let url = Self.baseURL.appendingPathComponent(Self.accountPath).appendingPathComponent(address)
        return createFetchOperation(from: url, shouldUseCache: false)
    }

    func fetchCollection(for identifier: String) -> BaseOperation<[RMRKV2Collection]> {
        let url = Self.baseURL.appendingPathComponent(Self.collectionPath).appendingPathComponent(identifier)
        return createFetchOperation(from: url, shouldUseCache: false)
    }
}
