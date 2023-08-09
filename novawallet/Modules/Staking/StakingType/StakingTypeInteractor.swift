import UIKit
import RobinHood
import BigInt

final class StakingTypeInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: StakingTypeInteractorOutputProtocol?
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let directStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let nominationPoolsRestrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let directStakingRecommendationMediator: RelaychainStakingRecommendationMediating
    let nominationPoolRecommendationMediator: RelaychainStakingRecommendationMediating
    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingSelectionMethod: StakingSelectionMethod

    private var balanceProvider: StreamableProvider<AssetBalance>?

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingSelectionMethod: StakingSelectionMethod,
        directStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        nominationPoolsRestrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        directStakingRecommendationMediator: RelaychainStakingRecommendationMediating,
        nominationPoolRecommendationMediator: RelaychainStakingRecommendationMediating,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingSelectionMethod = stakingSelectionMethod
        self.directStakingRestrictionsBuilder = directStakingRestrictionsBuilder
        self.nominationPoolsRestrictionsBuilder = nominationPoolsRestrictionsBuilder
        self.directStakingRecommendationMediator = directStakingRecommendationMediator
        self.nominationPoolRecommendationMediator = nominationPoolRecommendationMediator
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
    }

    deinit {
        clear(streamableProvider: &balanceProvider)
        directStakingRestrictionsBuilder.stop()
        nominationPoolsRestrictionsBuilder.stop()
    }

    private func performAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let chainAssetId = chainAsset.chainAssetId

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    private func provideDirectStakingRecommendation() {
        directStakingRecommendationMediator.delegate = self
        directStakingRecommendationMediator.update(amount: 0)
        directStakingRecommendationMediator.startRecommending()
    }

    private func provideNominationPoolStakingRecommendation() {
        nominationPoolRecommendationMediator.delegate = self
        nominationPoolRecommendationMediator.update(amount: 0)
        nominationPoolRecommendationMediator.startRecommending()
    }
}

extension StakingTypeInteractor: StakingTypeInteractorInputProtocol {
    func setup() {
        performAssetBalanceSubscription()
        [
            directStakingRestrictionsBuilder,
            nominationPoolsRestrictionsBuilder
        ].forEach {
            $0.delegate = self
            $0.start()
        }
    }

    func change(stakingTypeSelection: StakingTypeSelection) {
        switch stakingTypeSelection {
        case .direct:
            provideDirectStakingRecommendation()
        case .nominationPool:
            provideNominationPoolStakingRecommendation()
        }
    }
}

extension StakingTypeInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == chainAsset.chain.chainId,
            assetId == chainAsset.asset.assetId,
            accountId == selectedAccount.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            let balance = balance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )
            presenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            break
        }
    }
}

extension StakingTypeInteractor: RelaychainStakingRestrictionsBuilderDelegate {
    func restrictionsBuilder(
        _ builder: RelaychainStakingRestrictionsBuilding,
        didPrepare restrictions: RelaychainStakingRestrictions
    ) {
        if builder === directStakingRestrictionsBuilder {
            presenter?.didReceive(directStakingRestrictions: restrictions)
        } else if builder === nominationPoolsRestrictionsBuilder {
            presenter?.didReceive(nominationPoolRestrictions: restrictions)
        }
    }

    func restrictionsBuilder(
        _: RelaychainStakingRestrictionsBuilding,
        didReceive error: Error
    ) {
        presenter?.didReceive(error: .restrictions(error))
    }
}

extension StakingTypeInteractor: RelaychainStakingRecommendationDelegate {
    func didReceive(
        recommendation: RelaychainStakingRecommendation,
        amount _: BigUInt
    ) {
        presenter?.didReceive(method: .recommendation(recommendation))
        directStakingRecommendationMediator.stopRecommending()
        nominationPoolRecommendationMediator.stopRecommending()
    }

    func didReceiveRecommendation(
        error: Error
    ) {
        presenter?.didReceive(error: .recommendation(error))
    }
}
