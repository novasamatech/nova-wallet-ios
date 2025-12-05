import Foundation
@testable import novawallet

final class DummySigningWrapperFactory: SigningWrapperFactoryProtocol {
    func createSigningWrapper(
        giftSigningData: GiftSigningData
    ) -> SigningWrapperProtocol {
        try! DummySigner(
            cryptoType: giftSigningData.ethereumBased ? .ethereumEcdsa : .sr25519
        )
    }

    func createSigningWrapper(
        for _: String,
        accountResponse _: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        try! DummySigner(cryptoType: MultiassetCryptoType.sr25519)
    }

    func createSigningWrapper(
        for _: MetaEthereumAccountResponse
    ) -> SigningWrapperProtocol {
        try! DummySigner(cryptoType: MultiassetCryptoType.ethereumEcdsa)
    }

    func createEthereumSigner(for _: MetaEthereumAccountResponse) -> SignatureCreatorProtocol {
        try! DummySigner(cryptoType: MultiassetCryptoType.ethereumEcdsa)
    }
}
