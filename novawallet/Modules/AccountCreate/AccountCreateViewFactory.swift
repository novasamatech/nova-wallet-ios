import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory {
    private static func createViewForWallet(
        name: String,
        wireframe: AccountCreateWireframeProtocol
    ) -> AccountCreateViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let presenter = AccountCreatePresenter(walletName: name)

        let view = AccountCreateViewController(presenter: presenter, localizationManager: localizationManager)

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.localizationManager = localizationManager

        return view
    }

    // TODO: Fix this
    private static func createViewForReplace(
        metaAccountModel _: MetaAccountModel,
        chainModelId _: ChainModel.Id,
        isEthereumBased _: Bool,
        wireframe _: AccountCreateWireframeProtocol
    ) -> OldAccountCreateViewProtocol? {
        nil
//        let view = OldAccountCreateViewController(nib: R.nib.accountCreateViewController)
//
//        let presenter = OldAddChainAccount.AccountCreatePresenter(
//            metaAccountModel: metaAccountModel,
//            chainModelId: chainModelId,
//            isEthereumBased: isEthereumBased
//        )
//
//        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())
//
//        view.presenter = presenter
//        presenter.view = view
//        presenter.interactor = interactor
//        presenter.wireframe = wireframe
//        interactor.presenter = presenter
//
//        let localizationManager = LocalizationManager.shared
//        view.localizationManager = localizationManager
//        presenter.localizationManager = localizationManager
//
//        return view
    }
}

// MARK: - AccountCreateViewFactoryProtocol

extension AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = AccountCreateWireframe()
        return createViewForWallet(name: model.username, wireframe: wireframe)
    }

    static func createViewForAdding(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = AddAccount.AccountCreateWireframe()
        return createViewForWallet(name: model.username, wireframe: wireframe)
    }

    static func createViewForSwitch(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = SwitchAccount.AccountCreateWireframe()
        return createViewForWallet(name: model.username, wireframe: wireframe)
    }

    static func createViewForReplaceChainAccount(
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        isEthereumBased: Bool
    ) -> OldAccountCreateViewProtocol? {
        let wireframe = OldAddChainAccount.AccountCreateWireframe()

        return createViewForReplace(
            metaAccountModel: metaAccountModel,
            chainModelId: chainModelId,
            isEthereumBased: isEthereumBased,
            wireframe: wireframe
        )
    }
}
