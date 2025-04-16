import UIKit
import NovaCrypto
import Operation_iOS

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol?

    let walletRequestFactory: WalletCreationRequestFactoryProtocol

    init(
        walletRequestFactory: WalletCreationRequestFactoryProtocol
    ) {
        self.walletRequestFactory = walletRequestFactory
    }

    private func provideAvailableCrypto() {
        let availableCrypto = MetaAccountAvailableCryptoTypes(
            availableCryptoTypes: [.sr25519, .ed25519, .substrateEcdsa],
            defaultCryptoType: .sr25519
        )

        presenter?.didReceive(availableCrypto: availableCrypto)
    }

    private func generateMnemonicMetadata() throws -> MetaAccountCreationMetadata {
        let mnemonic = try walletRequestFactory.generateMnemonic()

        return MetaAccountCreationMetadata(mnemonic: mnemonic.allWords())
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        provideAvailableCrypto()
    }

    func provideMnemonic() {
        do {
            let metadata = try generateMnemonicMetadata()
            presenter?.didReceive(metadata: metadata)
        } catch {
            presenter?.didReceiveMnemonicGeneration(error: error)
        }
    }
}
