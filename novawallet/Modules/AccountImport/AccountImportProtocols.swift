import IrohaCrypto
import SoraFoundation

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: SecretSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol?)
    func setPassword(viewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)
}

protocol AccountImportPresenterProtocol: AnyObject {
    func setup()
    func activateUpload()
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
