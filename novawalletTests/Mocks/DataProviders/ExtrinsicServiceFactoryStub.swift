import Foundation
@testable import novawallet

final class ExtrinsicServiceFactoryStub: ExtrinsicServiceFactoryProtocol {
    let extrinsicService: ExtrinsicServiceProtocol
    let signingWraper: SigningWrapperProtocol

    init(extrinsicService: ExtrinsicServiceProtocol, signingWraper: SigningWrapperProtocol) {
        self.extrinsicService = extrinsicService
        self.signingWraper = signingWraper
    }

    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol {
        return extrinsicService
    }

    func createSigningWrapper(
        accountItem: AccountItem,
        connectionItem: ConnectionItem
    ) -> SigningWrapperProtocol {
        signingWraper
    }

    func createSigningWrapper(metaId: String, account: ChainAccountResponse) -> SigningWrapperProtocol {
        signingWraper
    }

    func createService(
        accountId: AccountId,
        chainFormat: ChainFormat,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }
}
