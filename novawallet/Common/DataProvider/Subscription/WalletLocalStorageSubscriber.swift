import Foundation
import RobinHood

protocol WalletLocalStorageSubscriber where Self: AnyObject {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol { get }

    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler { get }

    func subscribeToAssetBalanceProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) -> StreamableProvider<AssetBalance>?

    func subscribeToAccountBalanceProvider(
        for accountId: AccountId
    ) -> StreamableProvider<AssetBalance>?

    func subscribeAllBalancesProvider() -> StreamableProvider<AssetBalance>?

    func subscribeToAllLocksProvider(
        for accountId: AccountId
    ) -> StreamableProvider<AssetLock>?

    func subscribeToLocksProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) -> StreamableProvider<AssetLock>?
}

extension WalletLocalStorageSubscriber {
    func subscribeToAssetBalanceProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) -> StreamableProvider<AssetBalance>? {
        guard let provider = try? walletLocalSubscriptionFactory.getAssetBalanceProvider(
            for: accountId,
            chainId: chainId,
            assetId: assetId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<AssetBalance>]) in
            let assetBalance = changes.reduceToLastChange()

            self?.walletLocalSubscriptionHandler.handleAssetBalance(
                result: .success(assetBalance),
                accountId: accountId,
                chainId: chainId,
                assetId: assetId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler.handleAssetBalance(
                result: .failure(error),
                accountId: accountId,
                chainId: chainId,
                assetId: assetId
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }

    func subscribeToAccountBalanceProvider(
        for accountId: AccountId
    ) -> StreamableProvider<AssetBalance>? {
        guard let provider = try? walletLocalSubscriptionFactory.getAccountBalanceProvider(
            for: accountId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<AssetBalance>]) in
            self?.walletLocalSubscriptionHandler.handleAccountBalance(
                result: .success(changes),
                accountId: accountId
            )

            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler.handleAccountBalance(
                result: .failure(error),
                accountId: accountId
            )

            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }

    func subscribeAllBalancesProvider() -> StreamableProvider<AssetBalance>? {
        guard let provider = try? walletLocalSubscriptionFactory.getAllBalancesProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<AssetBalance>]) in
            self?.walletLocalSubscriptionHandler.handleAllBalances(result: .success(changes))

            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler.handleAllBalances(result: .failure(error))

            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }

    func subscribeToAllLocksProvider(
        for accountId: AccountId
    ) -> StreamableProvider<AssetLock>? {
        guard let locksProvider = try? walletLocalSubscriptionFactory.getLocksProvider(for: accountId) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<AssetLock>]) in
            self?.walletLocalSubscriptionHandler.handleAccountLocks(result: .success(changes), accountId: accountId)
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler.handleAccountLocks(
                result: .failure(error),
                accountId: accountId
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        locksProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return locksProvider
    }

    func subscribeToLocksProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) -> StreamableProvider<AssetLock>? {
        guard
            let locksProvider = try? walletLocalSubscriptionFactory.getLocksProvider(
                for: accountId,
                chainId: chainId,
                assetId: assetId
            ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<AssetLock>]) in
            self?.walletLocalSubscriptionHandler.handleAccountLocks(
                result: .success(changes),
                accountId: accountId,
                chainId: chainId,
                assetId: assetId
            )
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler.handleAccountLocks(
                result: .failure(error),
                accountId: accountId,
                chainId: chainId,
                assetId: assetId
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        locksProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return locksProvider
    }
}

extension WalletLocalStorageSubscriber where Self: WalletLocalSubscriptionHandler {
    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler { self }
}
