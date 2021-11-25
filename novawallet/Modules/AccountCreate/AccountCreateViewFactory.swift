import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory {
    private static func createViewForUsername(
        model: UsernameSetupModel,
        wireframe: AccountCreateWireframeProtocol
    ) -> OldAccountCreateViewProtocol? {
        let view = OldAccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(usernameSetup: model)

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }

    private static func createViewForReplace(
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        isEthereumBased: Bool,
        wireframe: AccountCreateWireframeProtocol
    ) -> OldAccountCreateViewProtocol? {
        let view = OldAccountCreateViewController(nib: R.nib.accountCreateViewController)

        let presenter = OldAddChainAccount.AccountCreatePresenter(
            metaAccountModel: metaAccountModel,
            chainModelId: chainModelId,
            isEthereumBased: isEthereumBased
        )

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}

// MARK: - AccountCreateViewFactoryProtocol

extension AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(model: UsernameSetupModel) -> OldAccountCreateViewProtocol? {
        let wireframe = AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            wireframe: wireframe
        )
    }

    static func createViewForAdding(model: UsernameSetupModel) -> OldAccountCreateViewProtocol? {
        let wireframe = AddAccount.AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            wireframe: wireframe
        )
    }

    static func createViewForSwitch(model: UsernameSetupModel) -> OldAccountCreateViewProtocol? {
        let wireframe = SwitchAccount.AccountCreateWireframe()
        return createViewForUsername(model: model, wireframe: wireframe)
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
