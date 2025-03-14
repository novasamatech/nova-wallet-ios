import Foundation
import Operation_iOS

extension MythosStakingPallet {
    typealias DecodedUserStake = ChainStorageDecodedItem<MythosStakingPallet.UserStake>
    typealias DecodedReleaseQueue = ChainStorageDecodedItem<MythosStakingPallet.ReleaseQueue>
}

protocol MythosStakingLocalSubscriptionFactoryProtocol {
    func getMinStakeProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getCurrentSessionProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedU32>

    func getUserStakeProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<MythosStakingPallet.DecodedUserStake>

    func getReleaseQueueProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<MythosStakingPallet.DecodedReleaseQueue>

    func getAutoCompoundProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<DecodedPercent>

    func getCollatorRewardsPercentageProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPercent>

    func getExtraRewardProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>
}

final class MythosStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    MythosStakingLocalSubscriptionFactoryProtocol {
    func getMinStakeProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(
            for: chainId,
            storagePath: MythosStakingPallet.minStakePath
        )
    }

    func getCurrentSessionProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedU32> {
        try getPlainProvider(
            for: chainId,
            storagePath: MythosStakingPallet.currentSessionPath
        )
    }

    func getUserStakeProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<MythosStakingPallet.DecodedUserStake> {
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: MythosStakingPallet.userStakePath
        )
    }

    func getReleaseQueueProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<MythosStakingPallet.DecodedReleaseQueue> {
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: MythosStakingPallet.releaseQueuesPath
        )
    }

    func getAutoCompoundProvider(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> AnyDataProvider<DecodedPercent> {
        try getAccountProvider(
            for: chainId,
            accountId: accountId,
            storagePath: MythosStakingPallet.autoCompoundPath
        )
    }

    func getCollatorRewardsPercentageProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPercent> {
        try getPlainProvider(
            for: chainId,
            storagePath: MythosStakingPallet.collatorRewardPercentagePath
        )
    }

    func getExtraRewardProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(
            for: chainId,
            storagePath: MythosStakingPallet.extraRewardPath,
            shouldUseFallback: true
        )
    }
}
