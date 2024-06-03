import UIKit
import IrohaCrypto
import RobinHood

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol

    init(
        mnemonicCreator: IRMnemonicCreatorProtocol
    ) {
        self.mnemonicCreator = mnemonicCreator
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func provideMetadata() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

            let metadata = MetaAccountCreationMetadata(
                mnemonic: mnemonic.allWords(),
                availableCryptoTypes: [.sr25519, .ed25519, .substrateEcdsa],
                defaultCryptoType: .sr25519
            )

            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }

    func createMetadata() -> MetaAccountCreationMetadata? {
        guard let mnemonic = try? mnemonicCreator.randomMnemonic(.entropy128) else { return .none }

        let metadata = MetaAccountCreationMetadata(
            mnemonic: mnemonic.allWords(),
            availableCryptoTypes: [.sr25519, .ed25519, .substrateEcdsa],
            defaultCryptoType: .sr25519
        )

        return metadata
    }
}
