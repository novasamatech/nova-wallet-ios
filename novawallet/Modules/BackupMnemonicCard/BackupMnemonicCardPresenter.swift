import Foundation
import IrohaCrypto
import SubstrateSdk

final class BackupMnemonicCardPresenter {
    weak var view: BackupMnemonicCardViewProtocol?
    let wireframe: BackupMnemonicCardWireframeProtocol
    let interactor: BackupMnemonicCardInteractor

    private var mnemonic: IRMnemonicProtocol?
    private var metaAccount: MetaAccountModel

    private var iconGenerator = NovaIconGenerator()

    init(
        interactor: BackupMnemonicCardInteractor,
        wireframe: BackupMnemonicCardWireframeProtocol,
        metaAccount: MetaAccountModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.metaAccount = metaAccount
    }

    private func generateIcon() -> IdentifiableDrawableIconViewModel? {
        let optIcon = metaAccount.walletIdenticonData().flatMap { try? iconGenerator.generateFromAccountId($0) }
        let iconViewModel = optIcon.map {
            IdentifiableDrawableIconViewModel(
                .init(icon: $0),
                identifier: metaAccount.metaId
            )
        }

        return iconViewModel
    }
}

extension BackupMnemonicCardPresenter: BackupMnemonicCardPresenterProtocol {
    func setup() {
        print(view)
        view?.update(with:
            .init(
                walletName: metaAccount.name,
                walletIcon: generateIcon(),
                state: .mnemonicNotVisible
            )
        )
    }

    func mnemonicCardTapped() {
        interactor.fetchMnemonic()
    }
}

extension BackupMnemonicCardPresenter: BackupMnemonicCardInteractorOutputProtocol {
    func didReceive(mnemonic: IRMnemonicProtocol) {
        self.mnemonic = mnemonic

        view?.update(with:
            .init(
                walletName: metaAccount.name,
                walletIcon: generateIcon(),
                state: .mnemonicVisible(words: mnemonic.allWords())
            )
        )
    }

    func didReceive(error _: Error) {}
}
