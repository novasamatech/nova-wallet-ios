import Foundation
@testable import novawallet

final class DummySigningWrapperFactory: SigningWrapperFactoryProtocol {
    func createSigningWrapper(
        for metaId: String,
        accountResponse: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        try! DummySigner(cryptoType: MultiassetCryptoType.sr25519)
    }

    func createSigningWrapper(
        for ethereumAccountResponse: MetaEthereumAccountResponse
    ) -> SigningWrapperProtocol {
        try! DummySigner(cryptoType: MultiassetCryptoType.ethereumEcdsa)
    }
}
