import IrohaCrypto
import SoraFoundation

protocol OldAccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedSubstrateCrypto(model: TitleWithSubtitleViewModel)
    func setSelectedEthereumCrypto(model: TitleWithSubtitleViewModel)
    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol?)
    func setEthereumDerivationPath(viewModel: InputViewModelProtocol?)

    func didCompleteCryptoTypeSelection()
    func didValidateSubstrateDerivationPath(_ status: FieldStatus)
    func didValidateEthereumDerivationPath(_ status: FieldStatus)
}

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

// TODO: Remove
protocol OldAccountCreatePresenterProtocol: AnyObject {
    func setup()
    func selectCryptoType()
    func activateInfo()
    func validate()
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
    // TODO: Remove
    func confirm(
        from view: OldAccountCreateViewProtocol?,
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    )

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

    // TODO: Remove
    func presentCryptoTypeSelection(
        from view: OldAccountCreateViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    // TODO: Remove
    func confirm(
        from view: OldAccountCreateViewProtocol?,
        request: ChainAccountImportMnemonicRequest,
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id
    )

    func confirm(
        from view: AccountCreateViewProtocol?,
        request: ChainAccountImportMnemonicRequest,
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id
    )
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
        from _: OldAccountCreateViewProtocol?,
        request _: MetaAccountCreationRequest,
        metadata _: MetaAccountCreationMetadata
    ) {}

    func confirm(
        from _: OldAccountCreateViewProtocol?,
        request _: ChainAccountImportMnemonicRequest,
        metaAccountModel _: MetaAccountModel,
        chainModelId _: ChainModel.Id
    ) {}

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

    // TODO: Remove
    func presentCryptoTypeSelection(
        from _: OldAccountCreateViewProtocol?,
        availableTypes _: [MultiassetCryptoType],
        selectedType _: MultiassetCryptoType,
        delegate _: ModalPickerViewControllerDelegate?,
        context _: AnyObject?
    ) {}
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(model: UsernameSetupModel) -> AccountCreateViewProtocol?
    static func createViewForAdding(model: UsernameSetupModel) -> AccountCreateViewProtocol?
    static func createViewForSwitch(model: UsernameSetupModel) -> AccountCreateViewProtocol?

    static func createViewForReplaceChainAccount(
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        isEthereumBased: Bool
    ) -> AccountCreateViewProtocol?
}
