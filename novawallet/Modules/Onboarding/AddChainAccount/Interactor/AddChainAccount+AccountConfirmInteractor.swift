import UIKit
import Keystore_iOS
import NovaCrypto
import Operation_iOS

extension AddChainAccount {
    final class AccountConfirmInteractor: BaseChainAccountConfirmInteractor {
        private(set) var settings: SelectedWalletSettings
        let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
        let walletUpdateMediator: WalletUpdateMediating
        let eventCenter: EventCenterProtocol

        private let callStore = CancellableCallStore()

        init(
            metaAccountModel: MetaAccountModel,
            request: ChainAccountImportMnemonicRequest,
            chainModelId: ChainModel.Id,
            mnemonic: IRMnemonicProtocol,
            metaAccountOperationFactory: MetaAccountOperationFactoryProtocol,
            walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
            walletUpdateMediator: WalletUpdateMediating,
            operationQueue: OperationQueue,
            settings: SelectedWalletSettings,
            eventCenter: EventCenterProtocol
        ) {
            self.settings = settings
            self.walletRepository = walletRepository
            self.walletUpdateMediator = walletUpdateMediator
            self.eventCenter = eventCenter

            super.init(
                request: request,
                metaAccountModel: metaAccountModel,
                chainModelId: chainModelId,
                mnemonic: mnemonic,
                metaAccountOperationFactory: metaAccountOperationFactory,
                operationQueue: operationQueue
            )
        }

        override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
            guard !callStore.hasCall else {
                return
            }

            let managedWalletWrapper = createManagedWalletOperation(using: importOperation)

            managedWalletWrapper.addDependency(operations: [importOperation])

            let persistentWrapper = walletUpdateMediator.saveChanges {
                let updatedManagedWallet = try managedWalletWrapper
                    .targetOperation
                    .extractNoCancellableResultData()
                return .init(newOrUpdatedItems: [updatedManagedWallet])
            }

            persistentWrapper.addDependency(wrapper: managedWalletWrapper)

            let settingsSetupOperation: ClosureOperation<Void> = ClosureOperation {
                let metaAccountItem = try importOperation.extractNoCancellableResultData()

                if let savedAccountItem = self.settings.value,
                   savedAccountItem.identifier == metaAccountItem.identifier {
                    self.settings.setup()
                    self.eventCenter.notify(with: SelectedWalletSwitched())
                }
            }

            settingsSetupOperation.addDependency(persistentWrapper.targetOperation)

            let dependencies = [importOperation]
                + persistentWrapper.allOperations
                + managedWalletWrapper.allOperations

            let wrapper = CompoundOperationWrapper(
                targetOperation: settingsSetupOperation,
                dependencies: dependencies
            )

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: callStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.eventCenter.notify(with: ChainAccountChanged())
                    self?.presenter?.didCompleteConfirmation()
                case let .failure(error):
                    self?.presenter?.didReceive(error: error)
                }
            }
        }
    }
}

// MARK: - Private

private extension AddChainAccount.AccountConfirmInteractor {
    func createManagedWalletOperation(
        using importOperation: BaseOperation<MetaAccountModel>
    ) -> CompoundOperationWrapper<ManagedMetaAccountModel> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let metaAccountItem = try importOperation.extractNoCancellableResultData()

            let fetchOperation = walletRepository.fetchOperation(
                by: { metaAccountItem.identifier },
                options: .init()
            )
            let mapOperation: ClosureOperation<ManagedMetaAccountModel> = ClosureOperation {
                let updatedManagedWallet = try fetchOperation
                    .extractNoCancellableResultData()?
                    .replacingInfo(metaAccountItem)

                guard let updatedManagedWallet else {
                    throw BaseOperationError.parentOperationCancelled
                }

                return updatedManagedWallet
            }

            mapOperation.addDependency(fetchOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [fetchOperation]
            )
        }
    }
}
