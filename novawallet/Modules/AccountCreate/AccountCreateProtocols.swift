import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func displayMnemonic()
}

protocol AccountCreatePresenterProtocol: AnyObject {
    func setup()
    func activateAdvanced()
    func prepareToDisplayMnemonic()
    func proceed()
}

protocol AccountCreateInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(metadata: MetaAccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAdvancedSettings(
        from view: AccountCreateViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings,
        delegate: AdvancedWalletSettingsDelegate
    )

    func confirm(
        from view: AccountCreateViewProtocol?,
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    )

    func confirm(
        from view: AccountCreateViewProtocol?,
        request: ChainAccountImportMnemonicRequest,
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id
    )

    func cancelFlow(from view: AccountCreateViewProtocol?)
}

extension AccountCreateWireframeProtocol {
    func showAdvancedSettings(
        from view: AccountCreateViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings,
        delegate: AdvancedWalletSettingsDelegate
    ) {
        guard let advancedView = AdvancedWalletViewFactory.createView(
            for: secretSource,
            advancedSettings: settings,
            delegate: delegate
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: advancedView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func confirm(
        from _: AccountCreateViewProtocol?,
        request _: MetaAccountCreationRequest,
        metadata _: MetaAccountCreationMetadata
    ) {}

    func confirm(
        from _: AccountCreateViewProtocol?,
        request _: ChainAccountImportMnemonicRequest,
        metaAccountModel _: MetaAccountModel,
        chainModelId _: ChainModel.Id
    ) {}

    func cancelFlow(from view: AccountCreateViewProtocol?) {
        guard let view = view else { return }
        view.controller.navigationController?.popViewController(animated: true)
    }
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(walletName: String) -> AccountCreateViewProtocol?
    static func createViewForAdding(walletName: String) -> AccountCreateViewProtocol?
    static func createViewForSwitch(walletName: String) -> AccountCreateViewProtocol?

    static func createViewForReplaceChainAccount(
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        isEthereumBased: Bool
    ) -> AccountCreateViewProtocol?
}
