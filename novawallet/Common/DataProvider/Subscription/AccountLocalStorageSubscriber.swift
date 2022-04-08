import Foundation
import RobinHood

protocol AccountLocalStorageSubscriber: AnyObject {
    var accountProviderFactory: AccountProviderFactoryProtocol { get }
    var accountSubscriptionHandler: AccountLocalSubscriptionHandler { get }

    func subscribeForAccountId(
        _ accountId: AccountId,
        chain: ChainModel
    ) -> StreamableProvider<MetaAccountModel>
}

extension AccountLocalStorageSubscriber {
    func subscribeForAccountId(
        _ accountId: AccountId,
        chain: ChainModel
    ) -> StreamableProvider<MetaAccountModel> {
        let provider = accountProviderFactory.createStreambleProvider(for: accountId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<MetaAccountModel>]) in
            let maybeAccount: MetaChainAccountResponse? = changes.compactMap { change in
                switch change {
                case let .insert(newItem), let .update(newItem):
                    if let accountResponse = newItem.fetchMetaChainAccount(for: chain.accountRequest()) {
                        return accountResponse.chainAccount.accountId == accountId ? accountResponse : nil
                    } else {
                        return nil
                    }
                case .delete:
                    return nil
                }
            }.first

            self?.accountSubscriptionHandler.handleAccountResponse(
                result: .success(maybeAccount),
                accountId: accountId,
                chain: chain
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.accountSubscriptionHandler.handleAccountResponse(
                result: .failure(error),
                accountId: accountId,
                chain: chain
            )
            return
        }

        let options = StreamableProviderObserverOptions()
        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}

extension AccountLocalStorageSubscriber where Self: AccountLocalSubscriptionHandler {
    var accountSubscriptionHandler: AccountLocalSubscriptionHandler { self }
}
