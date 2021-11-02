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

            persistentOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    switch persistentOperation.result {
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

            persistentOperation.addDependency(importOperation)

            operationManager.enqueue(
                operations: [importOperation, persistentOperation],
                in: .transient
            )
        }
    }
}
