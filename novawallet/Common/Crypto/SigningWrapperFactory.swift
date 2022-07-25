import Foundation
import SoraKeystore

protocol SigningWrapperFactoryProtocol {
    func createSigningWrapper(
        for metaId: String,
        accountResponse: ChainAccountResponse
    ) -> SigningWrapperProtocol

    func createSigningWrapper(
        for ethereumAccountResponse: MetaEthereumAccountResponse
    ) -> SigningWrapperProtocol
}

final class SigningWrapperFactory: SigningWrapperFactoryProtocol {
    let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol = Keychain()) {
        self.keystore = keystore
    }

    func createSigningWrapper(
        for metaId: String,
        accountResponse: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        switch accountResponse.type {
        case .secrets:
            return SigningWrapper(keystore: keystore, metaId: metaId, accountResponse: accountResponse)
        case .watchOnly:
            return NoKeysSigningWrapper()
        }
    }

    func createSigningWrapper(
        for ethereumAccountResponse: MetaEthereumAccountResponse
    ) -> SigningWrapperProtocol {
        switch ethereumAccountResponse.type {
        case .secrets:
            return SigningWrapper(keystore: keystore, ethereumAccountResponse: ethereumAccountResponse)
        case .watchOnly:
            return NoKeysSigningWrapper()
        }
    }
}
