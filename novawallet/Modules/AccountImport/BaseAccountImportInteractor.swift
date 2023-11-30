import UIKit
import IrohaCrypto
import SubstrateSdk
import RobinHood
import SoraKeystore

class BaseAccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let metaAccountOperationFactory: MetaAccountOperationFactoryProtocol
    let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType

    init(
        metaAccountOperationFactory: MetaAccountOperationFactoryProtocol,
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        availableCryptoTypes: [MultiassetCryptoType],
        defaultCryptoType: MultiassetCryptoType
    ) {
        self.metaAccountOperationFactory = metaAccountOperationFactory
        self.metaAccountRepository = metaAccountRepository
        self.operationManager = operationManager
        self.keystoreImportService = keystoreImportService
        self.availableCryptoTypes = availableCryptoTypes
        self.defaultCryptoType = defaultCryptoType
    }

    private func setupKeystoreImportObserver() {
        keystoreImportService.add(observer: self)
        handleIfNeededKeystoreImport()
    }

    private func handleIfNeededKeystoreImport() {
        if let definition = keystoreImportService.definition {
            keystoreImportService.clear()

            do {
                switch definition {
                case let .keystore(keystoreDefinition):
                    let jsonData = try JSONEncoder().encode(keystoreDefinition)
                    let info = try AccountImportJsonFactory().createInfo(from: keystoreDefinition)

                    if let text = String(data: jsonData, encoding: .utf8) {
                        presenter.didSuggestKeystore(text: text, preferredInfo: info)
                    }
                case let .mnemonic(mnemonicDefinition):
                    let text = mnemonicDefinition.mnemonic.toString()
                    presenter.didSuggestKeystore(
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
        setupKeystoreImportObserver()
    }

    func importAccountWithMnemonic(request: MetaAccountImportMnemonicRequest) {
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

        let accountOperation = metaAccountOperationFactory.newSecretsMetaAccountOperation(
            request: creationRequest,
            mnemonic: mnemonic
        )

        importAccountUsingOperation(accountOperation)
    }

    func importAccountWithSeed(request: MetaAccountImportSeedRequest) {
        let operation = metaAccountOperationFactory.newSecretsMetaAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(request: MetaAccountImportKeystoreRequest) {
        let operation = metaAccountOperationFactory.newSecretsMetaAccountOperation(request: request)
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

        let operation = metaAccountOperationFactory
            .replaceChainAccountOperation(for: wallet, request: request, chainId: chainId)
        importAccountUsingOperation(operation)
    }

    func importAccountWithSeed(
        chainId: ChainModel.Id,
        request: ChainAccountImportSeedRequest,
        into wallet: MetaAccountModel
    ) {
        let operation = metaAccountOperationFactory
            .replaceChainAccountOperation(for: wallet, request: request, chainId: chainId)
        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(
        chainId: ChainModel.Id,
        request: ChainAccountImportKeystoreRequest,
        into wallet: MetaAccountModel
    ) {
        let operation = metaAccountOperationFactory
            .replaceChainAccountOperation(for: wallet, request: request, chainId: chainId)
        importAccountUsingOperation(operation)
    }

    func deriveMetadataFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data),
            let info = try? AccountImportJsonFactory().createInfo(from: definition) {
            presenter.didSuggestKeystore(text: keystore, preferredInfo: info)
        }
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: SecretImportDefinition?) {
        handleIfNeededKeystoreImport()
    }

    func didReceiveError(secretImportError: ErrorContentConvertible & Error) {
        presenter.didReceiveAccountImport(error: secretImportError)
    }
}
