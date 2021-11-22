import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
    func setSelectedSubstrateCrypto(model: TitleWithSubtitleViewModel)
    func setSelectedEthereumCrypto(model: TitleWithSubtitleViewModel)
    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol?)
    func setEthereumDerivationPath(viewModel: InputViewModelProtocol?)

    func didCompleteCryptoTypeSelection()
    func didValidateSubstrateDerivationPath(_ status: FieldStatus)
    func didValidateEthereumDerivationPath(_ status: FieldStatus)
}

protocol AccountCreatePresenterProtocol: AnyObject {
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
    func confirm(
        from view: AccountCreateViewProtocol?,
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    )

    func presentCryptoTypeSelection(
        from view: AccountCreateViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func confirm(
        from view: AccountCreateViewProtocol?,
        request: ChainAccountImportMnemonicRequest,
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id
    )
}

extension AccountCreateWireframeProtocol {
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
