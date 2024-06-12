import Foundation
import Operation_iOS

protocol TuringStakingLocalSubscriptionFactoryProtocol {
    func getTotalUnvestedProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>
}

final class TuringStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    TuringStakingLocalSubscriptionFactoryProtocol {
    func getTotalUnvestedProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        let storagePath = TuringStaking.totalUnvestedPath

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            storagePath,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: storagePath,
            shouldUseFallback: false
        )
    }
}
