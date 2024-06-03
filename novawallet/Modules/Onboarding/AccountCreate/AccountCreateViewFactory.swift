import Foundation
import IrohaCrypto
import SoraUI
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory {
    private static func createViewForWallet(
        name: String,
        wireframe: AccountCreateWireframeProtocol
    ) -> AccountCreateViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let checkboxListViewModelFactory = CheckboxListViewModelFactory(localizationManager: localizationManager)
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)

        let presenter = AccountCreatePresenter(
            walletName: name,
            localizationManager: localizationManager,
            checkboxListViewModelFactory: checkboxListViewModelFactory,
            mnemonicViewModelFactory: mnemonicViewModelFactory
        )

        let appearanceAnimator = FadeAnimator(
            from: 0.0,
            to: 1.0,
            options: .curveLinear
        )

        let view = AccountCreateViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            appearanceAnimator: appearanceAnimator
        )

        let interactor = AccountCreateInteractor(walletRequestFactory: WalletCreationRequestFactory())

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createViewForReplace(
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        isEthereumBased: Bool,
        wireframe: AccountCreateWireframeProtocol
    ) -> AccountCreateViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let checkboxListViewModelFactory = CheckboxListViewModelFactory(localizationManager: localizationManager)
        let mnemonicViewModelFactory = MnemonicViewModelFactory(localizationManager: localizationManager)

        let presenter = AddChainAccount.AccountCreatePresenter(
            metaAccountModel: metaAccountModel,
            chainModelId: chainModelId,
            isEthereumBased: isEthereumBased,
            localizationManager: localizationManager,
            checkboxListViewModelFactory: checkboxListViewModelFactory,
            mnemonicViewModelFactory: mnemonicViewModelFactory
        )

        let appearanceAnimator = FadeAnimator(
            from: 0.0,
            to: 1.0,
            options: .curveLinear
        )

        let view = AccountCreateViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            appearanceAnimator: appearanceAnimator
        )

        let interactor = AccountCreateInteractor(walletRequestFactory: WalletCreationRequestFactory())

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}

// MARK: - AccountCreateViewFactoryProtocol

extension AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(walletName: String) -> AccountCreateViewProtocol? {
        let wireframe = AccountCreateWireframe()
        return createViewForWallet(name: walletName, wireframe: wireframe)
    }

    static func createViewForAdding(walletName: String) -> AccountCreateViewProtocol? {
        let wireframe = AddAccount.AccountCreateWireframe()
        return createViewForWallet(name: walletName, wireframe: wireframe)
    }

    static func createViewForSwitch(walletName: String) -> AccountCreateViewProtocol? {
        let wireframe = SwitchAccount.AccountCreateWireframe()
        return createViewForWallet(name: walletName, wireframe: wireframe)
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
