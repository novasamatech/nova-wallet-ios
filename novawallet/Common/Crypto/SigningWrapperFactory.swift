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
    let settingsManager: SettingsManagerProtocol

    init(
        uiPresenter: TransactionSigningPresenting = TransactionSigningPresenter(),
        keystore: KeystoreProtocol = Keychain(),
        settingsManager: SettingsManagerProtocol = SettingsManager.shared
    ) {
        self.uiPresenter = uiPresenter
        self.keystore = keystore
        self.settingsManager = settingsManager
    }

    func createSigningWrapper(
        for metaId: String,
        accountResponse: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        switch accountResponse.type {
        case .secrets:
            return SigningWrapper(
                keystore: keystore,
                metaId: metaId,
                accountResponse: accountResponse,
                settingsManager: settingsManager
            )
        case .watchOnly:
            return NoKeysSigningWrapper()
        case .paritySigner:
            return ParitySignerSigningWrapper(
                uiPresenter: uiPresenter,
                metaId: metaId,
                chainId: accountResponse.chainId
            )
        case .ledger:
            return LedgerSigningWrapper(
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
            return SigningWrapper(
                keystore: keystore,
                ethereumAccountResponse: ethereumAccountResponse,
                settingsManager: settingsManager
            )
        case .watchOnly:
            return NoKeysSigningWrapper()
        case .paritySigner:
            return NoSigningSupportWrapper(type: .paritySigner)
        case .ledger:
            return NoSigningSupportWrapper(type: .ledger)
        }
    }

    func createEthereumSigner(for ethereumAccountResponse: MetaEthereumAccountResponse) -> SignatureCreatorProtocol {
        switch ethereumAccountResponse.type {
        case .secrets:
            return EthereumSigner(keystore: keystore, ethereumAccountResponse: ethereumAccountResponse)
        case .watchOnly:
            return NoKeysSigningWrapper()
        case .paritySigner:
            return NoSigningSupportWrapper(type: .paritySigner)
        case .ledger:
            return NoSigningSupportWrapper(type: .ledger)
        }
    }
}

extension SigningWrapperFactory {
    static func createSigner(from metaAccountResponse: MetaChainAccountResponse) -> SigningWrapperProtocol {
        SigningWrapperFactory().createSigningWrapper(
            for: metaAccountResponse.metaId,
            accountResponse: metaAccountResponse.chainAccount
        )
    }
}
