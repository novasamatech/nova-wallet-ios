import Foundation
import RobinHood
import BigInt
import CommonWallet

extension StakingMainInteractor {
    func handle(stashItem: StashItem?) {
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(dataProvider: &payeeProvider)
        clear(singleValueProvider: &rewardAnalyticsProvider)
        clear(streamableProvider: &controllerAccountProvider)
        clear(streamableProvider: &stashAccountProvider)

        if
            let stashItem = stashItem,
            let chainAsset = selectedChainAsset,
            let stashAccountId = try? stashItem.stash.toAccountId(),
            let controllerId = try? stashItem.controller.toAccountId() {
            let chainId = chainAsset.chain.chainId
            ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainId)
            nominatorProvider = subscribeNomination(for: stashAccountId, chainId: chainId)
            validatorProvider = subscribeValidator(for: stashAccountId, chainId: chainId)
            payeeProvider = subscribePayee(for: stashAccountId, chainId: chainId)

            if let rewardApi = chainAsset.chain.externalApi?.staking {
                totalRewardProvider = subscribeTotalReward(
                    for: stashItem.stash,
                    api: rewardApi,
                    assetPrecision: Int16(chainAsset.asset.precision)
                )
            } else {
                let zeroReward = TotalRewardItem(address: stashItem.stash, amount: AmountDecimal(value: 0))
                presenter.didReceive(totalReward: zeroReward)
            }

            subscribeToControllerAccount(address: stashItem.controller, chain: chainAsset.chain)

            if stashItem.controller != stashItem.stash {
                subscribeToStashAccount(address: stashItem.stash, chain: chainAsset.chain)
            }

            // TODO: Temporary disable Analytics feature
            // subscribeRewardsAnalytics(for: stashItem.stash)
        }

        presenter?.didReceive(stashItem: stashItem)
    }

    func performPriceSubscription() {
        guard let chainAsset = stakingSettings.value else {
            presenter.didReceive(priceError: PersistentValueSettingsError.missingValue)
            return
        }

        guard let priceId = chainAsset.asset.priceId else {
            presenter.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId)
    }

    func performAccountInfoSubscription() {
        guard
            let selectedAccount = selectedWalletSettings.value,
            let chainAsset = stakingSettings.value else {
            presenter.didReceive(balanceError: PersistentValueSettingsError.missingValue)
            return
        }

        guard let accountResponse = selectedAccount.fetch(
            for: chainAsset.chain.accountRequest()
        ) else {
            presenter.didReceive(balanceError: ChainAccountFetchingError.accountNotExists)
            return
        }

        balanceProvider = subscribeToAccountInfoProvider(
            for: accountResponse.accountId,
            chainId: chainAsset.chain.chainId
        )
    }

    func clearStashControllerSubscription() {
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(dataProvider: &payeeProvider)
        clear(singleValueProvider: &rewardAnalyticsProvider)
        clear(streamableProvider: &stashControllerProvider)
    }

    func performStashControllerSubscription() {
        guard let address = selectedAccount?.toAddress() else {
            presenter.didReceive(stashItemError: ChainAccountFetchingError.accountNotExists)
            return
        }

        stashControllerProvider = subscribeStashItemProvider(for: address)
    }

    func subscribeToControllerAccount(address: AccountAddress, chain: ChainModel) {
        guard controllerAccountProvider == nil, let accountId = try? address.toAccountId() else {
            return
        }

        controllerAccountProvider = subscribeForAccountId(accountId, chain: chain)
    }

    func subscribeToStashAccount(address: AccountAddress, chain: ChainModel) {
        guard stashAccountProvider == nil, let accountId = try? address.toAccountId() else {
            return
        }

        stashAccountProvider = subscribeForAccountId(accountId, chain: chain)
    }

    func clearNominatorsLimitProviders() {
        clear(dataProvider: &minNominatorBondProvider)
        clear(dataProvider: &counterForNominatorsProvider)
        clear(dataProvider: &maxNominatorsCountProvider)
    }

    func performNominatorLimitsSubscripion() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        minNominatorBondProvider = subscribeToMinNominatorBond(for: chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainId)
    }

    private func subscribeRewardsAnalytics(for stash: AccountAddress) {
        if let analyticsURL = selectedChainAsset?.chain.externalApi?.staking?.url {
            rewardAnalyticsProvider = subscribeWeaklyRewardAnalytics(for: stash, url: analyticsURL)
        } else {
            presenter.didReceieve(
                subqueryRewards: .success(nil),
                period: .week
            )
        }
    }
}

extension StakingMainInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        switch result {
        case let .success(stashItem):
            handle(stashItem: stashItem)
            presenter.didReceive(stashItem: stashItem)
        case let .failure(error):
            presenter.didReceive(stashItemError: error)
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledgerInfo):
            presenter.didReceive(ledgerInfo: ledgerInfo)
        case let .failure(error):
            presenter.didReceive(ledgerInfoError: error)
        }
    }

    func handleNomination(
        result: Result<Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(nomination):
            presenter.didReceive(nomination: nomination)
        case let .failure(error):
            presenter.didReceive(nominationError: error)
        }
    }

    func handleValidator(
        result: Result<ValidatorPrefs?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(validatorPrefs):
            presenter.didReceive(validatorPrefs: validatorPrefs)
        case let .failure(error):
            presenter.didReceive(validatorError: error)
        }
    }

    func handlePayee(
        result: Result<RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(payee):
            presenter.didReceive(payee: payee)
        case let .failure(error):
            presenter.didReceive(payeeError: error)
        }
    }

    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for _: AccountAddress,
        api _: ChainModel.ExternalApi
    ) {
        switch result {
        case let .success(totalReward):
            presenter.didReceive(totalReward: totalReward)
        case let .failure(error):
            presenter.didReceive(totalRewardError: error)
        }
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMinNominatorBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMaxNominatorsCount(result: result)
    }
}

extension StakingMainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if let chainAsset = stakingSettings.value, chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter.didReceive(price: priceData)
            case let .failure(error):
                presenter.didReceive(priceError: error)
            }
        }
    }
}

extension StakingMainInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(accountInfo):
            presenter.didReceive(accountInfo: accountInfo)
        case let .failure(error):
            presenter.didReceive(balanceError: error)
        }
    }
}

extension StakingMainInteractor: StakingAnalyticsLocalStorageSubscriber,
    StakingAnalyticsLocalSubscriptionHandler {
    func handleWeaklyRewardAnalytics(
        result: Result<[SubqueryRewardItemData]?, Error>,
        address _: AccountAddress,
        url _: URL
    ) {
        presenter.didReceieve(subqueryRewards: result, period: .week)
    }
}

extension StakingMainInteractor: AccountLocalSubscriptionHandler, AccountLocalStorageSubscriber {
    func handleAccountResponse(
        result: Result<MetaChainAccountResponse?, Error>,
        accountId: AccountId,
        chain _: ChainModel
    ) {
        switch result {
        case let .success(account):
            presenter.didReceiveAccount(account, for: accountId)
        case .failure:
            presenter.didReceiveAccount(nil, for: accountId)
        }
    }
}
