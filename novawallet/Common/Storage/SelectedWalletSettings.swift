import Foundation
import RobinHood

final class SelectedWalletSettings: PersistentValueSettings<MetaAccountModel> {
    static let shared = SelectedWalletSettings(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )

    let storageFacade: StorageFacadeProtocol

    let operationQueue: OperationQueue

    init(storageFacade: StorageFacadeProtocol, operationQueue: OperationQueue) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
    }

    override func performSetup(completionClosure: @escaping (Result<MetaAccountModel?, Error>) -> Void) {
        let mapper = MetaAccountMapper()
        let repository = storageFacade.createRepository(
            filter: NSPredicate.selectedMetaAccount(),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = {
            do {
                let result = try operation.extractNoCancellableResultData().first
                completionClosure(.success(result))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperation(operation)
    }

    override func performSave(
        value: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        let mapper = ManagedMetaAccountMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let maybeCurrentAccountOperation = internalValue.map {
            repository.fetchOperation(by: $0.identifier, options: options)
        }

        let newAccountOperation = repository.fetchOperation(by: value.identifier, options: options)

        let saveOperation = repository.saveOperation({
            var accountsToSave: [ManagedMetaAccountModel] = []

            if let currentAccount = try maybeCurrentAccountOperation?.extractNoCancellableResultData() {
                accountsToSave.append(
                    ManagedMetaAccountModel(
                        info: currentAccount.info,
                        isSelected: false,
                        order: currentAccount.order
                    )
                )
            }

            if let newAccount = try newAccountOperation.extractNoCancellableResultData() {
                accountsToSave.append(
                    ManagedMetaAccountModel(
                        info: value,
                        isSelected: true,
                        order: newAccount.order
                    )
                )
            } else {
                accountsToSave.append(
                    ManagedMetaAccountModel(info: value, isSelected: true)
                )
            }

            return accountsToSave
        }, { [] })

        var dependencies: [Operation] = [newAccountOperation]

        if let currentAccountOperation = maybeCurrentAccountOperation {
            dependencies.append(currentAccountOperation)
        }

        dependencies.forEach { saveOperation.addDependency($0) }

        saveOperation.completionBlock = {
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                completionClosure(.success(value))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations(dependencies + [saveOperation], waitUntilFinished: false)
    }

    override func performRemove(
        value: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel?, Error>) -> Void
    ) {
        let mapper = ManagedMetaAccountMapper()
        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder],
            mapper: AnyCoreDataMapper(mapper)
        )

        let fetchAllWalletsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let newSelectedWalletOperation = ClosureOperation<ManagedMetaAccountModel?> {
            let allWallets = try fetchAllWalletsOperation.extractNoCancellableResultData()

            guard let selectedWallet = allWallets.first(where: { $0.isSelected }) else {
                return allWallets.first(where: { $0.identifier != value.identifier })
            }

            if
                selectedWallet.identifier == value.identifier,
                let firstWalletByOrder = allWallets.first(where: { $0.identifier != value.identifier }) {
                return firstWalletByOrder.replacingSelection(true)
            } else {
                return nil
            }
        }

        newSelectedWalletOperation.addDependency(fetchAllWalletsOperation)

        let saveOperation = repository.saveOperation({
            if let newSelectedWallet = try newSelectedWalletOperation.extractNoCancellableResultData() {
                return [newSelectedWallet]
            } else {
                return []
            }
        }, {
            [value.identifier]
        })

        saveOperation.addDependency(newSelectedWalletOperation)

        saveOperation.completionBlock = {
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                let newSelectedWallet = try newSelectedWalletOperation.extractNoCancellableResultData()
                completionClosure(.success(newSelectedWallet?.info))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations(
            [fetchAllWalletsOperation, newSelectedWalletOperation, saveOperation],
            waitUntilFinished: false
        )
    }
}
