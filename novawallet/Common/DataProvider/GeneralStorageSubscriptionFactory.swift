import Foundation
import Operation_iOS
import SubstrateSdk

protocol GeneralStorageSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber>

    func getAccountInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo>
}

final class GeneralStorageSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    GeneralStorageSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber> {
        let codingPath = SystemPallet.blockNumberPath
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }

    func getAccountInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo> {
        let codingPath = SystemPallet.accountPath

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

extension GeneralStorageSubscriptionFactory {
    static let shared = GeneralStorageSubscriptionFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        storageFacade: SubstrateDataStorageFacade.shared,
        operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue),
        logger: Logger.shared
    )
}
