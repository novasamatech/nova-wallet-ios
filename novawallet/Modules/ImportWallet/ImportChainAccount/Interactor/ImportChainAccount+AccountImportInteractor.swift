import UIKit
import NovaCrypto
import SubstrateSdk
import Operation_iOS
import Keystore_iOS

extension ImportChainAccount {
    final class AccountImportInteractor: BaseAccountImportInteractor {
        private(set) var settings: SelectedWalletSettings
        let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
        let walletUpdateMediator: WalletUpdateMediating
        let eventCenter: EventCenterProtocol

        private let callStore = CancellableCallStore()

        init(
            metaAccountOperationFactoryProvider: MetaAccountOperationFactoryProviding,
            operationQueue: OperationQueue,
            settings: SelectedWalletSettings,
            walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
            walletUpdateMediator: WalletUpdateMediating,
            secretImportService: SecretImportServiceProtocol,
            eventCenter: EventCenterProtocol
        ) {
            self.settings = settings
            self.walletRepository = walletRepository
            self.walletUpdateMediator = walletUpdateMediator
            self.eventCenter = eventCenter

            super.init(
                metaAccountOperationFactoryProvider: metaAccountOperationFactoryProvider,
                operationQueue: operationQueue,
                secretImportService: secretImportService
            )
        }

        override func importAccountUsingOperation(
            _ importOperation: BaseOperation<MetaAccountModel>
        ) {
            guard !callStore.hasCall else {
                return
            }

            let managedWalletWrapper = createManagedWalletOperation(using: importOperation)

            managedWalletWrapper.addDependency(operations: [importOperation])

            let persistentWrapper = walletUpdateMediator.saveChanges {
                let updatedManagedWallet = try managedWalletWrapper
                    .targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return .init(newOrUpdatedItems: [updatedManagedWallet])
            }

            persistentWrapper.addDependency(wrapper: managedWalletWrapper)

            let saveOperation: ClosureOperation<Void> = ClosureOperation {
                let metaAccountItem = try importOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                if let savedAccountItem = self.settings.value,
                   savedAccountItem.identifier == metaAccountItem.identifier {
                    self.settings.save(value: metaAccountItem)
                    self.eventCenter.notify(with: SelectedWalletSwitched())
                }
            }

            saveOperation.addDependency(persistentWrapper.targetOperation)

            let dependencies = [importOperation]
                + persistentWrapper.allOperations
                + managedWalletWrapper.allOperations

            let wrapper = CompoundOperationWrapper(
                targetOperation: saveOperation,
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
                    self?.presenter?.didCompleteAccountImport()
                case let .failure(error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }
    }
}

// MARK: - Private

private extension ImportChainAccount.AccountImportInteractor {
    func createManagedWalletOperation(
        using importOperation: BaseOperation<MetaAccountModel>
    ) -> CompoundOperationWrapper<ManagedMetaAccountModel> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let metaAccountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

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
