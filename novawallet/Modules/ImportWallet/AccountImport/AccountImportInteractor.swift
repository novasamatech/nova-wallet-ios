import UIKit
import NovaCrypto
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

final class AccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SelectedWalletSettings
    private(set) var eventCenter: EventCenterProtocol

    init(
        metaAccountOperationFactoryProvider: MetaAccountOperationFactoryProviding,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        settings: SelectedWalletSettings,
        secretImportService: SecretImportServiceProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(
            metaAccountOperationFactoryProvider: metaAccountOperationFactoryProvider,
            metaAccountRepository: accountRepository,
            operationManager: operationManager,
            secretImportService: secretImportService,
            availableCryptoTypes: MultiassetCryptoType.substrateTypeList,
            defaultCryptoType: .sr25519
        )
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            self?.settings.save(value: accountItem)

            return accountItem
        }

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    self?.settings.setup()
                    self?.eventCenter.notify(with: SelectedWalletSwitched())
                    self?.eventCenter.notify(with: NewWalletImported())
                    self?.presenter?.didCompleteAccountImport()

                case let .failure(error):
                    self?.presenter?.didReceiveAccountImport(error: error)

                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        saveOperation.addDependency(importOperation)

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }
}
