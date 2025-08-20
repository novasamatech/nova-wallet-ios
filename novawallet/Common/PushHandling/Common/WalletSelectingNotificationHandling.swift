import Foundation
import Foundation_iOS
import Operation_iOS

protocol WalletSelectingNotificationHandling: AnyObject {
    var settings: SelectedWalletSettings { get }
    var eventCenter: EventCenterProtocol { get }
    var settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings> { get }
    var walletsRepository: AnyDataProviderRepository<MetaAccountModel> { get }
    var operationQueue: OperationQueue { get }
    var workingQueue: DispatchQueue { get }

    var callStore: CancellableCallStore { get }
}

// MARK: - Private

private extension WalletSelectingNotificationHandling {
    func trySelect(
        wallet: MetaAccountModel?,
        successClosure: @escaping () -> Void,
        failureClosure: @escaping (Error) -> Void
    ) {
        guard let wallet = wallet else {
            failureClosure(AssetDetailsHandlingError.unknownWallet)
            return
        }

        select(wallet: wallet) { error in
            if let error = error {
                failureClosure(AssetDetailsHandlingError.select(error))
            } else {
                successClosure()
            }
        }
    }

    func createTargetWalletWrapper(
        chainId: ChainModel.Id,
        address: AccountAddress,
        filter: ((MetaAccountModel) -> Bool)?
    ) -> CompoundOperationWrapper<MetaAccountModel?> {
        let settingsOperation = settingsRepository.fetchAllOperation(with: .init())
        let walletsOperation = walletsRepository.fetchAllOperation(with: .init())

        let mapOperation = ClosureOperation {
            let wallets = try settingsOperation.extractNoCancellableResultData().first?.wallets ?? []
            let metaAccounts = try walletsOperation.extractNoCancellableResultData()

            let wallet = self.findWallet(
                address: address,
                chainId: chainId,
                pushNotificationWallets: wallets,
                metaAccounts: metaAccounts,
                filter: filter
            )

            return wallet
        }

        mapOperation.addDependency(settingsOperation)
        mapOperation.addDependency(walletsOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [settingsOperation, walletsOperation]
        )
    }

    func findWallet(
        address: AccountAddress,
        chainId: ChainModel.Id,
        pushNotificationWallets: [Web3Alert.LocalWallet],
        metaAccounts: [MetaAccountModel],
        filter: ((MetaAccountModel) -> Bool)?
    ) -> MetaAccountModel? {
        guard let targetWallet = pushNotificationWallets.first(where: {
            if let specificAddress = $0.model.chainSpecific[chainId] {
                return specificAddress == address
            } else {
                return $0.model.baseSubstrate == address ||
                    $0.model.baseEthereum == address
            }
        }) else {
            return nil
        }

        return metaAccounts.first { metaAccount in
            guard let filter else {
                return metaAccount.metaId == targetWallet.metaId
            }

            return metaAccount.metaId == targetWallet.metaId && filter(metaAccount)
        }
    }

    func select(wallet: MetaAccountModel, completion: @escaping (Error?) -> Void) {
        settings.save(value: wallet, runningCompletionIn: workingQueue) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: SelectedWalletSwitched())
                completion(nil)
            case let .failure(error):
                completion(error)
            }
        }
    }
}

// MARK: - Internal

extension WalletSelectingNotificationHandling {
    func trySelectWallet(
        with address: AccountAddress,
        chainId: ChainModel.Id,
        filter: ((MetaAccountModel) -> Bool)? = nil,
        successClosure: @escaping () -> Void,
        failureClosure: @escaping (Error) -> Void
    ) {
        let targetWalletWrapper = createTargetWalletWrapper(
            chainId: chainId,
            address: address,
            filter: filter
        )

        executeCancellable(
            wrapper: targetWalletWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(result):
                self?.trySelect(
                    wallet: result,
                    successClosure: successClosure,
                    failureClosure: failureClosure
                )
            case let .failure(error):
                failureClosure(AssetDetailsHandlingError.select(error))
            }
        }
    }
}
