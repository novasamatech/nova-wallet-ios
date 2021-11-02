import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

extension AddChainAccount {
    final class AccountConfirmInteractor: BaseChainAccountConfirmInteractor {
        private(set) var settings: SelectedWalletSettings
        let eventCenter: EventCenterProtocol

        private var currentOperation: Operation?

        init(
            metaAccountModel: MetaAccountModel,
            request: ChainAccountImportMnemonicRequest,
            chainModelId: ChainModel.Id,
            mnemonic: IRMnemonicProtocol,
            metaAccountOperationFactory: MetaAccountOperationFactoryProtocol,
            metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
            operationManager: OperationManagerProtocol,
            settings: SelectedWalletSettings,
            eventCenter: EventCenterProtocol
        ) {
            self.settings = settings
            self.eventCenter = eventCenter

            super.init(
                request: request,
                metaAccountModel: metaAccountModel,
                chainModelId: chainModelId,
                mnemonic: mnemonic,
                metaAccountOperationFactory: metaAccountOperationFactory,
                metaAccountRepository: metaAccountRepository,
                operationManager: operationManager
            )
        }

        override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
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
                        self?.presenter?.didCompleteConfirmation()

                    case let .failure(error):
                        self?.presenter?.didReceive(error: error)

                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        self?.presenter?.didReceive(error: error)
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
