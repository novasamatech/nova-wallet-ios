import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory {
    private static func createViewForUsername(
        model: UsernameSetupModel,
        wireframe: AccountCreateWireframeProtocol
    ) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
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
    ) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)

        let presenter = AddChainAccount.AccountCreatePresenter(
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
    static func createViewForOnboarding(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            wireframe: wireframe
        )
    }

    static func createViewForAdding(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = AddAccount.AccountCreateWireframe()

        return createViewForUsername(
            model: model,
            wireframe: wireframe
        )
    }

    static func createViewForSwitch(model: UsernameSetupModel) -> AccountCreateViewProtocol? {
        let wireframe = SwitchAccount.AccountCreateWireframe()
        return createViewForUsername(model: model, wireframe: wireframe)
    }

    static func createViewForReplaceChainAccount(
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        isEthereumBased: Bool
    ) -> AccountCreateViewProtocol? {
        let wireframe = AddChainAccount.AccountCreateWireframe()

        return createViewForReplace(
            metaAccountModel: metaAccountModel,
            chainModelId: chainModelId,
            isEthereumBased: isEthereumBased,
            wireframe: wireframe
        )
    }
}
