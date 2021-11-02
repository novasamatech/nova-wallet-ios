import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setTitle(_ newTitle: String)
    func setSource(type: AccountImportSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol?)
    func setPassword(viewModel: InputViewModelProtocol)
    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>)
    func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)
    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol)
    func setEthereumDerivationPath(viewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)

    func didCompleteSourceTypeSelection()
    func didCompleteCryptoTypeSelection()
    func didCompleteAddressTypeSelection()

    func didValidateSubstrateDerivationPath(_ status: FieldStatus)
    func didValidateEthereumDerivationPath(_ status: FieldStatus)
}

protocol AccountImportPresenterProtocol: AnyObject {
    func setup()
    func updateTitle()
    func provideVisibilitySettings() -> AccountImportVisibility
    func selectSourceType()
    func selectCryptoType()
    func selectNetworkType()
    func activateUpload()
    func validateDerivationPath()
    func proceed()
}

protocol AccountImportInteractorInputProtocol: AnyObject {
    func setup()
    func importAccountWithMnemonic(request: MetaAccountImportMnemonicRequest)
    func importAccountWithSeed(request: MetaAccountImportSeedRequest)
    func importAccountWithKeystore(request: MetaAccountImportKeystoreRequest)

    func importAccountWithMnemonic(
        chainId: ChainModel.Id,
        request: ChainAccountImportMnemonicRequest,
        into wallet: MetaAccountModel
    )

    func importAccountWithSeed(
        chainId: ChainModel.Id,
        request: ChainAccountImportSeedRequest,
        into wallet: MetaAccountModel
    )

    func importAccountWithKeystore(
        chainId: ChainModel.Id,
        request: ChainAccountImportKeystoreRequest,
        into wallet: MetaAccountModel
    )

    func deriveMetadataFromKeystore(_ keystore: String)
}

protocol AccountImportInteractorOutputProtocol: AnyObject {
    func didReceiveAccountImport(metadata: MetaAccountImportMetadata)
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Error)
    func didSuggestKeystore(text: String, preferredInfo: MetaAccountImportPreferredInfo?)
}

protocol AccountImportWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(from view: AccountImportViewProtocol?)

    func presentSourceTypeSelection(
        from view: AccountImportViewProtocol?,
        availableSources: [AccountImportSource],
        selectedSource: AccountImportSource,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func presentCryptoTypeSelection(
        from view: AccountImportViewProtocol?,
        availableTypes: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )

    func presentNetworkTypeSelection(
        from view: AccountImportViewProtocol?,
        availableTypes: [Chain],
        selectedType: Chain,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

protocol AccountImportViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding() -> AccountImportViewProtocol?
    static func createViewForAdding() -> AccountImportViewProtocol?
    static func createViewForSwitch() -> AccountImportViewProtocol?

    static func createViewForReplaceChainAccount(
        modelId: ChainModel.Id,
        isEthereumBased: Bool,
        in wallet: MetaAccountModel
    ) -> AccountImportViewProtocol?
}

extension AccountImportWireframeProtocol {
    func presentNetworkTypeSelection(
        from _: AccountImportViewProtocol?,
        availableTypes _: [Chain],
        selectedType _: Chain,
        delegate _: ModalPickerViewControllerDelegate?,
        context _: AnyObject?
    ) {}
}
