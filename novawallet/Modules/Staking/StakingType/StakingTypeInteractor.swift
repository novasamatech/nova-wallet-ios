import UIKit
import RobinHood

final class StakingTypeInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingTypeInteractorOutputProtocol?
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let directStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let nominationPoolsRestrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    private var balanceProvider: StreamableProvider<AssetBalance>?
    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        directStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        nominationPoolsRestrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.directStakingRestrictionsBuilder = directStakingRestrictionsBuilder
        self.nominationPoolsRestrictionsBuilder = nominationPoolsRestrictionsBuilder
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
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

    deinit {
        clear(streamableProvider: &balanceProvider)
        [
            directStakingRestrictionsBuilder,
            nominationPoolsRestrictionsBuilder
        ].forEach {
            $0.stop()
        }
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
        didReceive _: Error
    ) {}
}
