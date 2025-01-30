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
}
