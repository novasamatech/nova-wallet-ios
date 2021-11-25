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
        from view: OldAccountCreateViewProtocol?,
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    )

    func presentCryptoTypeSelection(
        from view: OldAccountCreateViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func confirm(
        from view: OldAccountCreateViewProtocol?,
        request: ChainAccountImportMnemonicRequest,
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id
    )
}

extension AccountCreateWireframeProtocol {
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
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(model: UsernameSetupModel) -> OldAccountCreateViewProtocol?
    static func createViewForAdding(model: UsernameSetupModel) -> OldAccountCreateViewProtocol?
    static func createViewForSwitch(model: UsernameSetupModel) -> OldAccountCreateViewProtocol?

    static func createViewForReplaceChainAccount(
        metaAccountModel: MetaAccountModel,
        chainModelId: ChainModel.Id,
        isEthereumBased: Bool
    ) -> OldAccountCreateViewProtocol?
}
