import Foundation
import Keystore_iOS

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
            SigningWrapper(
                keystore: keystore,
                metaId: metaId,
                accountResponse: accountResponse,
                settingsManager: settingsManager
            )
        case .watchOnly:
            NoKeysSigningWrapper()
        case .paritySigner:
            ParitySignerSigningWrapper(
                uiPresenter: uiPresenter,
                metaId: metaId,
                chainId: accountResponse.chainId,
                type: .legacy
            )
        case .polkadotVault:
            ParitySignerSigningWrapper(
                uiPresenter: uiPresenter,
                metaId: metaId,
                chainId: accountResponse.chainId,
                type: .vault
            )
        case .ledger:
            LedgerSigningWrapper(
                uiPresenter: uiPresenter,
                metaId: metaId,
                chainId: accountResponse.chainId,
                ledgerWalletType: .legacy
            )
        case .proxied:
            ProxySigningWrapper(
                metaId: metaId,
                uiPresenter: uiPresenter
            )
        case .genericLedger:
            LedgerSigningWrapper(
                uiPresenter: uiPresenter,
                metaId: metaId,
                chainId: accountResponse.chainId,
                ledgerWalletType: .generic
            )
        case .multisig:
            MultisigSigningWrapper(
                metaId: metaId,
                uiPresenter: uiPresenter
            )
        }
    }

    func createSigningWrapper(
        for ethereumAccountResponse: MetaEthereumAccountResponse
    ) -> SigningWrapperProtocol {
        switch ethereumAccountResponse.type {
        case .secrets:
            SigningWrapper(
                keystore: keystore,
                ethereumAccountResponse: ethereumAccountResponse,
                settingsManager: settingsManager
            )
        case .watchOnly, .proxied:
            NoKeysSigningWrapper()
        case .paritySigner:
            NoSigningSupportWrapper(type: .paritySigner)
        case .polkadotVault:
            NoSigningSupportWrapper(type: .polkadotVault)
        case .ledger, .genericLedger:
            NoSigningSupportWrapper(type: .ledger)
        case .multisig:
            NoSigningSupportWrapper(type: .multisig)
        }
    }

    func createEthereumSigner(for ethereumAccountResponse: MetaEthereumAccountResponse) -> SignatureCreatorProtocol {
        switch ethereumAccountResponse.type {
        case .secrets:
            EthereumSigner(
                keystore: keystore,
                ethereumAccountResponse: ethereumAccountResponse,
                settingsManager: settingsManager
            )
        case .watchOnly, .proxied:
            NoKeysSigningWrapper()
        case .paritySigner:
            NoSigningSupportWrapper(type: .paritySigner)
        case .polkadotVault:
            NoSigningSupportWrapper(type: .polkadotVault)
        case .ledger, .genericLedger:
            NoSigningSupportWrapper(type: .ledger)
        case .multisig:
            NoSigningSupportWrapper(type: .multisig)
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
