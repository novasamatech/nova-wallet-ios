import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

protocol StakingLocalSubscriptionFactoryProtocol {
    func getMinNominatorBondProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<BigUInt>>
    ) throws -> AnyDataProvider<DecodedBigUInt>

    func getCounterForNominatorsProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32>

    func getMaxNominatorsCountProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32>

    func getBagListSizeProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32>

    func getTotalIssuanceProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt>

    func getNominationProvider(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedNomination>

    func getValidatorProvider(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedValidator>

    func getLedgerInfoProvider(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedLedgerInfo>

    func getActiveEra(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedActiveEra>

    func getCurrentEra(for chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedEraIndex>

    func getPayee(for accountId: AccountId, chainId: ChainModel.Id) throws
        -> AnyDataProvider<DecodedPayee>

    func getStashItemProvider(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> StreamableProvider<StashItem>

    func getBagListNodeProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBagListNode>

    func getProxyListProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedProxyDefinition>
}

final class StakingLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    StakingLocalSubscriptionFactoryProtocol {
    func getMinNominatorBondProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<BigUInt>>
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        let codingPath = Staking.minNominatorBond
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        let fallback = StorageProviderSourceFallback(
            usesRuntimeFallback: false,
            missingEntryStrategy: missingEntryStrategy
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            fallback: fallback
        )
    }

    func getTotalIssuanceProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> {
        let codingPath = StorageCodingPath.totalIssuance
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getCounterForNominatorsProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32> {
        let codingPath = Staking.counterForNominators
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        let fallback = StorageProviderSourceFallback(
            usesRuntimeFallback: false,
            missingEntryStrategy: missingEntryStrategy
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            fallback: fallback
        )
    }

    func getMaxNominatorsCountProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32> {
        let codingPath = Staking.maxNominatorsCount
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        let fallback = StorageProviderSourceFallback(
            usesRuntimeFallback: false,
            missingEntryStrategy: missingEntryStrategy
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            fallback: fallback
        )
    }

    func getBagListSizeProvider(
        for chainId: ChainModel.Id,
        missingEntryStrategy: MissingRuntimeEntryStrategy<StringScaleMapper<UInt32>>
    ) throws -> AnyDataProvider<DecodedU32> {
        let possibleCodingPaths = BagList.possibleModuleNames.map {
            BagList.bagListSizePath(for: $0)
        }

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            BagList.defaultBagListSizePath,
            chainId: chainId
        )

        let fallback = StorageProviderSourceFallback(
            usesRuntimeFallback: false,
            missingEntryStrategy: missingEntryStrategy
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            possibleCodingPaths: possibleCodingPaths,
            fallback: fallback
        )
    }

    func getNominationProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedNomination> {
        let codingPath = Staking.nominators
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getValidatorProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedValidator> {
        let codingPath = Staking.validatorPrefs
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getLedgerInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedLedgerInfo> {
        let codingPath = Staking.stakingLedger
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getBagListNodeProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBagListNode> {
        let possibleCodingPaths = BagList.possibleModuleNames.map {
            BagList.bagListNode(for: $0)
        }

        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            BagList.defaultBagListNodePath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            possibleCodingPaths: possibleCodingPaths,
            shouldUseFallback: false
        )
    }

    func getActiveEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        let codingPath = Staking.activeEra
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getCurrentEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> {
        let codingPath = Staking.currentEra
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getPayee(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPayee> {
        let codingPath = Staking.payee
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getStashItemProvider(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> StreamableProvider<StashItem> {
        clearIfNeeded()

        let identifier = "stashItem" + address + chainId

        if let provider = getProvider(for: identifier) as? StreamableProvider<StashItem> {
            return provider
        }

        let provider = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger
        ).createStashItemProvider(for: address, chainId: chainId)

        saveProvider(provider, for: identifier)

        return provider
    }

    func getProxyListProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedProxyDefinition> {
        clearIfNeeded()

        let codingPath = Proxy.proxyList
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(
            codingPath,
            accountId: accountId,
            chainId: chainId
        )

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }
}
