import Foundation
import SoraKeystore

protocol SigningWrapperFactoryProtocol {
    func createSigningWrapper(
        for metaId: String,
        accountResponse: ChainAccountResponse
    ) -> SigningWrapperProtocol
}

final class SigningWrapperFactory: SigningWrapperFactoryProtocol {
    let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func createSigningWrapper(
        for metaId: String,
        accountResponse: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        SigningWrapper(keystore: keystore, metaId: metaId, accountResponse: accountResponse)
    }
}
