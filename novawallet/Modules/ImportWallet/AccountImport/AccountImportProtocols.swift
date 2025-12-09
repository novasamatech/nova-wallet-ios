import NovaCrypto
import Foundation_iOS

protocol AccountImportViewProtocol: ControllerBackedProtocol {
    func setSource(type: SecretSource)
    func setSource(viewModel: InputViewModelProtocol)
    func setName(viewModel: InputViewModelProtocol?)
    func setPassword(viewModel: InputViewModelProtocol)
    func setUploadWarning(message: String)
    func setShouldShowAdvancedSettings(_ shouldShow: Bool)
}

protocol AccountImportPresenterProtocol: AnyObject {
    func setup()
    func activateUpload()
    func activateAdvancedSettings()
    func proceed()
    func activateScanner()
}

protocol AccountImportInteractorInputProtocol: AnyObject {
    func setup()

    func importAccountWithMnemonic(
        request: MetaAccountImportMnemonicRequest,
        from origin: SecretSource.Origin
    )

    func importAccountWithSeed(request: MetaAccountImportSeedRequest)
    func importAccountWithKeypair(request: MetaAccountImportKeypairRequest)
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

    func importAccountWithKeypair(
        chainId: ChainModel.Id,
        request: ChainAccountImportKeypairRequest,
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
    func didCompleteAccountImport()
    func didReceiveAccountImport(error: Error)
    func didSuggestSecret(text: String, preferredInfo: MetaAccountImportPreferredInfo)
}

protocol BaseAccountImportWireframeProtocol {
    func showModifiableAdvancedSettings(
        from view: AccountImportViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings,
        delegate: AdvancedWalletSettingsDelegate
    )

    func showReadonlyAdvancedSettings(
        from view: AccountImportViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings
    )
}

protocol AccountImportWireframeProtocol: BaseAccountImportWireframeProtocol, AlertPresentable, ErrorPresentable {
    func proceed(from view: AccountImportViewProtocol?)

    func presentScanner(
        from view: AccountImportViewProtocol?,
        importDelegate: SecretScanImportDelegate
    )
}
