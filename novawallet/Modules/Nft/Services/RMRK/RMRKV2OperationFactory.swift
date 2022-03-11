import Foundation
import RobinHood

protocol RMRKV2NftOperationFactoryProtocol {
    func fetchItemNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV2]>
    func fetchBirdNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV2]>
}

final class RMRKV2OperationFactory: BaseFetchOperationFactory {
    static let birdsPath = "/account-birds"
    static let itemsPath = "/account-items"
    static let baseURL = URL(string: "https://kanaria.rmrk.app/api/rmrk2")!
}

extension RMRKV2OperationFactory: RMRKV2NftOperationFactoryProtocol {
    func fetchBirdNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV2]> {
        let url = Self.baseURL.appendingPathComponent(Self.birdsPath).appendingPathComponent(address)
        return createFetchOperation(from: url, shouldUseCache: false)
    }

    func fetchItemNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV2]> {
        let url = Self.baseURL.appendingPathComponent(Self.itemsPath).appendingPathComponent(address)
        return createFetchOperation(from: url, shouldUseCache: false)
    }
}
