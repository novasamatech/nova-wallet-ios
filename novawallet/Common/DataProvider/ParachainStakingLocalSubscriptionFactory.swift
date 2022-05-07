import Foundation
import RobinHood

extension ParachainStaking {
    typealias DecodedRoundInfo = ChainStorageDecodedItem<ParachainStaking.RoundInfo>
    typealias DecodedInflationConfig = ChainStorageDecodedItem<ParachainStaking.InflationConfig>
    typealias DecodedParachainBondConfig = ChainStorageDecodedItem<
        ParachainStaking.ParachainBondConfig
    >
}

protocol ParachainStakingLocalSubscriptionFactoryProtocol {
    func getRoundProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedRoundInfo>

    func getTotalProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getCollatorCommissionProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getTotalIssuanceProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getStakedProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getInflationProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedInflationConfig>

    func getParachainBondProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedParachainBondConfig>
}

final class ParachainStakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    ParachainStakingLocalSubscriptionFactoryProtocol {
    private func getPlainProvider<T: Equatable & Decodable>(
        for chainId: ChainModel.Id,
        storagePath: StorageCodingPath
    ) throws -> AnyDataProvider<ChainStorageDecodedItem<T>> {
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

    func getRoundProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedRoundInfo> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.roundPath)
    }

    func getTotalProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.totalPath)
    }

    func getCollatorCommissionProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.collatorCommissionPath)
    }

    func getTotalIssuanceProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(for: chainId, storagePath: StorageCodingPath.totalIssuance)
    }

    func getStakedProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.stakedPath)
    }

    func getInflationProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedInflationConfig> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.inflationConfigPath)
    }

    func getParachainBondProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<ParachainStaking.DecodedParachainBondConfig> {
        try getPlainProvider(for: chainId, storagePath: ParachainStaking.parachainBondInfoPath)
    }
}
