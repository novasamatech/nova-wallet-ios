import Foundation
import Operation_iOS

extension MythosStakingPallet {
    typealias DecodedUserStake = ChainStorageDecodedItem<MythosStakingPallet.UserStake>
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
}
