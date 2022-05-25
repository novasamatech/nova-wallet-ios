import Foundation
@testable import novawallet

final class ExtrinsicServiceFactoryStub: ExtrinsicServiceFactoryProtocol {
    let extrinsicService: ExtrinsicServiceProtocol
    let signingWraper: SigningWrapperProtocol

    init(extrinsicService: ExtrinsicServiceProtocol, signingWraper: SigningWrapperProtocol) {
        self.extrinsicService = extrinsicService
        self.signingWraper = signingWraper
    }

    func createSigningWrapper(metaId: String, account: ChainAccountResponse) -> SigningWrapperProtocol {
        signingWraper
    }

    func createService(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }
}
