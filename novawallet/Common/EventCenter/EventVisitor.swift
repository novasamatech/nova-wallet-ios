import Foundation

protocol EventVisitorProtocol: AnyObject {
    func processSelectedConnectionChanged(event: SelectedConnectionChanged)

    func processTransactionHistoryUpdate(event: WalletTransactionListUpdated)
    func processPurchaseCompletion(event: PurchaseCompleted)
    func processTypeRegistryPrepared(event: TypeRegistryPrepared)
    func processEraStakersInfoChanged(event: EraStakersInfoChanged)
    func processEraNominationPoolsChanged(event: EraNominationPoolsChanged)
    func processStakingRewardsInfoChanged(event: StakingRewardInfoChanged)

    func processChainSyncDidStart(event: ChainSyncDidStart)
    func processChainSyncDidComplete(event: ChainSyncDidComplete)
    func processChainSyncDidFail(event: ChainSyncDidFail)

    func processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted)
    func processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted)
    func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)

    func processRuntimeCoderReady(event: RuntimeCoderCreated)
    func processRuntimeCoderCreationFailed(event: RuntimeCoderCreationFailed)

    func processHideZeroBalances(event: HideZeroBalancesChanged)

    func processBlockTimeChanged(event: BlockTimeChanged)

    func processAssetBalanceChanged(event: AssetBalanceChanged)

    func processNewWalletCreated(event: NewWalletCreated)
    func processWalletImported(event: NewWalletImported)
    func processWalletRemoved(event: WalletRemoved)
    func processChainAccountChanged(event: ChainAccountChanged)
    func processWalletsChanged(event: WalletsChanged)
    func processWalletNameChanged(event: WalletNameChanged)
    func processSelectedWalletChanged(event: SelectedWalletSwitched)
    func processNetworkEnableChanged(event: NetworkEnabledChanged)
}

extension EventVisitorProtocol {
    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {}
    func processTransactionHistoryUpdate(event _: WalletTransactionListUpdated) {}
    func processPurchaseCompletion(event _: PurchaseCompleted) {}
    func processTypeRegistryPrepared(event _: TypeRegistryPrepared) {}
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {}
    func processEraNominationPoolsChanged(event _: EraNominationPoolsChanged) {}
    func processStakingRewardsInfoChanged(event _: StakingRewardInfoChanged) {}

    func processChainSyncDidStart(event _: ChainSyncDidStart) {}
    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {}
    func processChainSyncDidFail(event _: ChainSyncDidFail) {}

    func processRuntimeCommonTypesSyncCompleted(event _: RuntimeCommonTypesSyncCompleted) {}
    func processRuntimeChainTypesSyncCompleted(event _: RuntimeChainTypesSyncCompleted) {}
    func processRuntimeChainMetadataSyncCompleted(event _: RuntimeMetadataSyncCompleted) {}

    func processRuntimeCoderReady(event _: RuntimeCoderCreated) {}
    func processRuntimeCoderCreationFailed(event _: RuntimeCoderCreationFailed) {}

    func processHideZeroBalances(event _: HideZeroBalancesChanged) {}

    func processBlockTimeChanged(event _: BlockTimeChanged) {}

    func processAssetBalanceChanged(event _: AssetBalanceChanged) {}

    func processNewWalletCreated(event _: NewWalletCreated) {}
    func processWalletImported(event _: NewWalletImported) {}
    func processWalletRemoved(event _: WalletRemoved) {}
    func processChainAccountChanged(event _: ChainAccountChanged) {}
    func processWalletsChanged(event _: WalletsChanged) {}
    func processWalletNameChanged(event _: WalletNameChanged) {}
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {}
    func processNetworkEnableChanged(event _: NetworkEnabledChanged) {}
}
