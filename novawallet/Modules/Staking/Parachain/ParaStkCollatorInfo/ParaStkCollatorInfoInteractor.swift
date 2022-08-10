import UIKit
import RobinHood

final class ParaStkCollatorInfoInteractor: AnyProviderAutoCleaning {
    weak var presenter: ParaStkCollatorInfoInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func subscribeDelegator() {
        clear(dataProvider: &delegatorProvider)

        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )
    }
}

extension ParaStkCollatorInfoInteractor: ParaStkCollatorInfoInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePrice(nil)
        }

        subscribeDelegator()
    }

    func reload() {
        priceProvider?.refresh()

        subscribeDelegator()
    }
}

extension ParaStkCollatorInfoInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(price):
            presenter?.didReceivePrice(price)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
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
            presenter?.didReceiveDelegator(delegator)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkCollatorInfoInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}
