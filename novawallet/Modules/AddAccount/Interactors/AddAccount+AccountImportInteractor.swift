import UIKit
import IrohaCrypto
import SubstrateSdk
import RobinHood
import SoraKeystore

extension AddAccount {
    final class AccountImportInteractor: BaseAccountImportInteractor {
        private(set) var settings: SelectedWalletSettings
        let eventCenter: EventCenterProtocol

        init(
            accountOperationFactory: MetaAccountOperationFactoryProtocol,
            accountRepository: AnyDataProviderRepository<MetaAccountModel>,
            operationManager: OperationManagerProtocol,
            settings: SelectedWalletSettings,
            keystoreImportService: KeystoreImportServiceProtocol,
            eventCenter: EventCenterProtocol
        ) {
            self.settings = settings
            self.eventCenter = eventCenter

            super.init(
                metaAccountOperationFactory: accountOperationFactory,
                metaAccountRepository: accountRepository,
                operationManager: operationManager,
                keystoreImportService: keystoreImportService,
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
                        self?.eventCenter.notify(with: SelectedAccountChanged())
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
}
