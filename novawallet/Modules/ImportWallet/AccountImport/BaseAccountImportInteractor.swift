import UIKit
import NovaCrypto
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

class BaseAccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let metaAccountOperationFactoryProvider: MetaAccountOperationFactoryProviding
    let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol
    let secretImportService: SecretImportServiceProtocol
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType

    init(
        metaAccountOperationFactoryProvider: MetaAccountOperationFactoryProviding,
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        secretImportService: SecretImportServiceProtocol,
        availableCryptoTypes: [MultiassetCryptoType],
        defaultCryptoType: MultiassetCryptoType
    ) {
        self.metaAccountOperationFactoryProvider = metaAccountOperationFactoryProvider
        self.metaAccountRepository = metaAccountRepository
        self.operationManager = operationManager
        self.secretImportService = secretImportService
        self.availableCryptoTypes = availableCryptoTypes
        self.defaultCryptoType = defaultCryptoType
    }

    private func setupSecretImportObserver() {
        secretImportService.add(observer: self)
        handleIfNeededSecretImport()
    }

    private func handleIfNeededSecretImport() {
        if let definition = secretImportService.definition {
            secretImportService.clear()

            do {
                switch definition {
                case let .keystore(keystoreDefinition):
                    let jsonData = try JSONEncoder().encode(keystoreDefinition)
                    let info = try AccountImportJsonFactory().createInfo(from: keystoreDefinition)

                    if let text = String(data: jsonData, encoding: .utf8) {
                        presenter.didSuggestSecret(text: text, preferredInfo: info)
                    }
                case let .mnemonic(mnemonicDefinition):
                    let text = mnemonicDefinition.mnemonic.toString()
                    presenter.didSuggestSecret(
                        text: text,
                        preferredInfo: mnemonicDefinition.prefferedInfo
                    )
                }
            } catch {
                presenter.didReceiveAccountImport(error: error)
            }
        }
    }

    private func provideMetadata() {
        let metadata = MetaAccountImportMetadata(
            availableCryptoTypes: availableCryptoTypes,
            defaultCryptoType: defaultCryptoType
        )

        presenter.didReceiveAccountImport(metadata: metadata)
    }

    func importAccountUsingOperation(_: BaseOperation<MetaAccountModel>) {}
}

extension BaseAccountImportInteractor: AccountImportInteractorInputProtocol {
    func setup() {
        provideMetadata()
        setupSecretImportObserver()
    }

    func importAccountWithMnemonic(
        request: MetaAccountImportMnemonicRequest,
        from origin: SecretSource.Origin
    ) {
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            presenter.didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            return
        }

        let creationRequest = MetaAccountCreationRequest(
            username: request.username,
            derivationPath: request.derivationPath,
            ethereumDerivationPath: request.ethereumDerivationPath,
            cryptoType: request.cryptoType
        )

        let accountOperation = metaAccountOperationFactoryProvider.createFactory(
            for: origin
        ).newSecretsMetaAccountOperation(
            request: creationRequest,
            mnemonic: mnemonic
        )

        importAccountUsingOperation(accountOperation)
    }

    func importAccountWithSeed(request: MetaAccountImportSeedRequest) {
        let operation = metaAccountOperationFactoryProvider.createAppDefaultFactory().newSecretsMetaAccountOperation(
            request: request
        )

        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(request: MetaAccountImportKeystoreRequest) {
        let operation = metaAccountOperationFactoryProvider.createAppDefaultFactory().newSecretsMetaAccountOperation(
            request: request
        )

        importAccountUsingOperation(operation)
    }

    func importAccountWithMnemonic(
        chainId: ChainModel.Id,
        request: ChainAccountImportMnemonicRequest,
        into wallet: MetaAccountModel
    ) {
        guard (try? mnemonicCreator.mnemonic(fromList: request.mnemonic)) != nil else {
            presenter.didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            return
        }

        let operation = metaAccountOperationFactoryProvider
            .createAppDefaultFactory()
            .replaceChainAccountOperation(for: wallet, request: request, chainId: chainId)
        importAccountUsingOperation(operation)
    }

    func importAccountWithSeed(
        chainId: ChainModel.Id,
        request: ChainAccountImportSeedRequest,
        into wallet: MetaAccountModel
    ) {
        let operation = metaAccountOperationFactoryProvider
            .createAppDefaultFactory()
            .replaceChainAccountOperation(for: wallet, request: request, chainId: chainId)
        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(
        chainId: ChainModel.Id,
        request: ChainAccountImportKeystoreRequest,
        into wallet: MetaAccountModel
    ) {
        let operation = metaAccountOperationFactoryProvider
            .createAppDefaultFactory()
            .replaceChainAccountOperation(for: wallet, request: request, chainId: chainId)
        importAccountUsingOperation(operation)
    }

    func deriveMetadataFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data),
            let info = try? AccountImportJsonFactory().createInfo(from: definition) {
            presenter.didSuggestSecret(text: keystore, preferredInfo: info)
        }
    }
}

extension BaseAccountImportInteractor: SecretImportObserver {
    func didUpdateDefinition(from _: SecretImportDefinition?) {
        handleIfNeededSecretImport()
    }

    func didReceiveError(secretImportError: ErrorContentConvertible & Error) {
        presenter.didReceiveAccountImport(error: secretImportError)
    }
}
