import UIKit
import IrohaCrypto
import SubstrateSdk
import RobinHood
import SoraKeystore

extension ImportChainAccount {
    final class AccountImportInteractor: BaseAccountImportInteractor {
        private(set) var settings: SelectedWalletSettings
        let eventCenter: EventCenterProtocol

        init(
            metaAccountOperationFactory: MetaAccountOperationFactoryProtocol,
            metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
            operationManager: OperationManagerProtocol,
            settings: SelectedWalletSettings,
            keystoreImportService: KeystoreImportServiceProtocol,
            eventCenter: EventCenterProtocol
        ) {
            self.settings = settings
            self.eventCenter = eventCenter

            super.init(
                metaAccountOperationFactory: metaAccountOperationFactory,
                metaAccountRepository: metaAccountRepository,
                operationManager: operationManager,
                keystoreImportService: keystoreImportService,
                supportedNetworks: Chain.allCases, // FIXME: Remove after interactors are done
                defaultNetwork: Chain.kusama // FIXME: Remove after interactors are done
            )
        }

        override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
            let persistentOperation = metaAccountRepository.saveOperation({
                let metaAccountItem = try importOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                return [metaAccountItem]
            }, { [] })

            persistentOperation.addDependency(importOperation)

            let saveOperation: ClosureOperation<Void> = ClosureOperation {
                let metaAccountItem = try importOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                if let savedAccountItem = self.settings.value,
                   savedAccountItem.identifier == metaAccountItem.identifier {
                    self.settings.save(value: metaAccountItem)
                    self.eventCenter.notify(with: SelectedAccountChanged())
                }
            }

            saveOperation.addDependency(importOperation)
            saveOperation.addDependency(persistentOperation)

            saveOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    switch saveOperation.result {
                    case .success:
                        self?.eventCenter.notify(with: ChainAccountChanged())
                        self?.presenter?.didCompleteAccountImport()

                    case let .failure(error):
                        self?.presenter?.didReceiveAccountImport(error: error)

                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        self?.presenter?.didReceiveAccountImport(error: error)
                    }
                }
            }

            operationManager.enqueue(
                operations: [importOperation, persistentOperation, saveOperation],
                in: .transient
            )
        }
    }
}
