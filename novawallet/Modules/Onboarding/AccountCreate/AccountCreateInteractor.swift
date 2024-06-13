import UIKit
import IrohaCrypto
import Operation_iOS

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let walletRequestFactory: WalletCreationRequestFactoryProtocol

    init(
        walletRequestFactory: WalletCreationRequestFactoryProtocol
    ) {
        self.walletRequestFactory = walletRequestFactory
    }

    private func generateMnemonicMetadata() throws -> MetaAccountCreationMetadata {
        let mnemonic = try walletRequestFactory.generateMnemonic()

        return MetaAccountCreationMetadata(
            mnemonic: mnemonic.allWords(),
            availableCryptoTypes: [.sr25519, .ed25519, .substrateEcdsa],
            defaultCryptoType: .sr25519
        )
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func provideMetadata() {
        do {
            let metadata = try generateMnemonicMetadata()
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }

    func createMetadata() -> MetaAccountCreationMetadata? {
        try? generateMnemonicMetadata()
    }
}
