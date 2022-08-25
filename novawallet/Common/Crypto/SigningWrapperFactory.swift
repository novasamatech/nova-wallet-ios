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

    func createEthereumSigner(for ethereumAccountResponse: MetaEthereumAccountResponse) -> SignatureCreatorProtocol
}

final class SigningWrapperFactory: SigningWrapperFactoryProtocol {
    let keystore: KeystoreProtocol

    let uiPresenter: TransactionSigningPresenting

    init(
        uiPresenter: TransactionSigningPresenting = TransactionSigningPresenter(),
        keystore: KeystoreProtocol = Keychain()
    ) {
        self.uiPresenter = uiPresenter
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
        case .paritySigner:
            return ParitySignerSigningWrapper(
                uiPresenter: uiPresenter,
                metaId: metaId,
                chainId: accountResponse.chainId
            )
        case .ledger:
            return ParitySignerSigningWrapper(
                uiPresenter: uiPresenter,
                metaId: metaId,
                chainId: accountResponse.chainId
            )
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
        case .paritySigner, .ledger:
            return NoSigningSupportWrapper()
        }
    }

    func createEthereumSigner(for ethereumAccountResponse: MetaEthereumAccountResponse) -> SignatureCreatorProtocol {
        switch ethereumAccountResponse.type {
        case .secrets:
            return EthereumSigner(keystore: keystore, ethereumAccountResponse: ethereumAccountResponse)
        case .watchOnly:
            return NoKeysSigningWrapper()
        case .paritySigner, .ledger:
            return NoSigningSupportWrapper()
        }
    }
}
