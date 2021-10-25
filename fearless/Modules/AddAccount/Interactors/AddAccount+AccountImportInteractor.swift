import UIKit
import IrohaCrypto
import FearlessUtils
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
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: operationManager,
                keystoreImportService: keystoreImportService,
                supportedNetworks: Chain.allCases, // FIXME: Remove after interactors are done
                defaultNetwork: Chain.kusama // FIXME: Remove after interactors are done
            )
        }

        private func importAccountItem(_ item: MetaAccountModel) {
            let checkOperation = accountRepository.fetchOperation(
                by: item.identifier,
                options: RepositoryFetchOptions()
            )

            let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
                if try checkOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) != nil {
                    throw AccountCreateError.duplicated
                }

                self?.settings.save(value: item)

                return item
            }

            saveOperation.addDependency(checkOperation)

            operationManager.enqueue(
                operations: [checkOperation, saveOperation],
                in: .transient
            )
        }

        override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
            importOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    switch importOperation.result {
                    case let .success(accountItem):
                        self?.importAccountItem(accountItem)
                    case let .failure(error):
                        self?.presenter?.didReceiveAccountImport(error: error)
                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        self?.presenter?.didReceiveAccountImport(error: error)
                    }
                }
            }

            operationManager.enqueue(operations: [importOperation], in: .transient)
        }
    }
}
