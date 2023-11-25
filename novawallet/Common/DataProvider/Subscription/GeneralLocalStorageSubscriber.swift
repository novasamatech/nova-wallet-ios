import Foundation
import RobinHood

protocol GeneralLocalStorageSubscriber: LocalStorageProviderObserving {
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }

    var generalLocalSubscriptionHandler: GeneralLocalStorageHandler { get }

    func subscribeToBlockNumber(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBlockNumber>?

    func subscribeAccountInfo(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedAccountInfo>?
}

extension GeneralLocalStorageSubscriber {
    func subscribeToBlockNumber(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBlockNumber>? {
        guard let blockNumberProvider = try? generalLocalSubscriptionFactory.getBlockNumberProvider(
            for: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedBlockNumber>]) in
            let blockNumber = changes.reduceToLastChange()
            self?.generalLocalSubscriptionHandler.handleBlockNumber(
                result: .success(blockNumber?.item?.value),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.generalLocalSubscriptionHandler.handleBlockNumber(
                result: .failure(error), chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        blockNumberProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return blockNumberProvider
    }

    func subscribeAccountInfo(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedAccountInfo>? {
        guard
            let provider = try? generalLocalSubscriptionFactory.getAccountInfoProvider(
                for: accountId,
                chainId: chainId
            ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] accountInfo in
                self?.generalLocalSubscriptionHandler.handleAccountInfo(
                    result: .success(accountInfo),
                    accountId: accountId,
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.generalLocalSubscriptionHandler.handleAccountInfo(
                    result: .failure(error),
                    accountId: accountId,
                    chainId: chainId
                )
            }
        )

        return provider
    }
}

extension GeneralLocalStorageSubscriber where Self: GeneralLocalStorageHandler {
    var generalLocalSubscriptionHandler: GeneralLocalStorageHandler { self }
}
