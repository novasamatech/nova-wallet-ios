import UIKit
import Operation_iOS

final class ParaStkCollatorInfoInteractor: CollatorStakingInfoInteractor, AnyProviderAutoCleaning {
    let selectedAccount: MetaChainAccountResponse
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol

    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory

        super.init(
            chainAsset: chainAsset,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager
        )
    }

    private func subscribeDelegator() {
        clear(dataProvider: &delegatorProvider)

        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    override func onSetup() {
        subscribeDelegator()
    }

    override func onReload() {
        subscribeDelegator()
    }
}

extension ParaStkCollatorInfoInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
    func handleParastakingDelegatorState(
        result: Result<ParachainStaking.Delegator?, Error>,
        for _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(delegator):
            let model = delegator.map { CollatorStakingDelegator(parachainDelegator: $0) }
            presenter?.didReceiveDelegator(model)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}
