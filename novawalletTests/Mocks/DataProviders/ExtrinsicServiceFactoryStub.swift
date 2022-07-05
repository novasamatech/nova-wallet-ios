import Foundation
@testable import novawallet

final class ExtrinsicServiceFactoryStub: ExtrinsicServiceFactoryProtocol {
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    let signingWraper: SigningWrapperProtocol

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        signingWraper: SigningWrapperProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol = ExtrinsicOperationFactoryStub()
    ) {
        self.extrinsicService = extrinsicService
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.signingWraper = signingWraper
    }

    func createSigningWrapper(metaId: String, account: ChainAccountResponse) -> SigningWrapperProtocol {
        signingWraper
    }

    func createOperationFactory(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicOperationFactory
    }

    func createService(
        accountId: AccountId,
        chain: ChainModel,
        cryptoType: MultiassetCryptoType
    ) -> ExtrinsicServiceProtocol {
        extrinsicService
    }
}
