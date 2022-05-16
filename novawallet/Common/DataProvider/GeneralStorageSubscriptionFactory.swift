import Foundation
import RobinHood
import SubstrateSdk

protocol GeneralStorageSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber>
}

final class GeneralStorageSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    GeneralStorageSubscriptionFactoryProtocol {
    func getBlockNumberProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedBlockNumber> {
        let codingPath = StorageCodingPath.blockNumber
        let localKey = try LocalStorageKeyFactory().createFromStoragePath(codingPath, chainId: chainId)

        return try getDataProvider(
            for: localKey,
            chainId: chainId,
            storageCodingPath: codingPath,
            shouldUseFallback: false
        )
    }
}
