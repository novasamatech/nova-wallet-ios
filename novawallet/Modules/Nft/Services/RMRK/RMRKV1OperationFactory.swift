import Foundation
import RobinHood

protocol RMRKV1NftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV1]>
}

final class RMRKV1OperationFactory: BaseFetchOperationFactory {
    static let accountPath = "/account"
    static let baseURL = URL(string: "https://singular.rmrk.app/api/rmrk1")!
}

extension RMRKV1OperationFactory: RMRKV1NftOperationFactoryProtocol {
    func fetchNfts(for address: AccountAddress) -> BaseOperation<[RMRKNftV1]> {
        let url = Self.baseURL.appendingPathComponent(Self.accountPath).appendingPathComponent(address)
        return createFetchOperation(from: url)
    }
}
