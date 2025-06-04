import Foundation
import Operation_iOS

protocol AssetHistoryFactoryFacadeProtocol {
    func createOperationFactory(
        for chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> WalletRemoteHistoryFactoryProtocol?
}

final class AssetHistoryFacade {
    func createSubqueryFactory(
        for chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> WalletRemoteHistoryFactoryProtocol? {
        let optApi = chainAsset.chain.externalApis?.history()?.first { option in
            option.serviceType == AssetHistoryServiceType.subquery.rawValue &&
                (
                    option.parameters?.assetType?.stringValue == nil ||
                        option.parameters?.assetType?.stringValue == chainAsset.asset.type
                )
        }

        guard let url = optApi?.url else {
            return nil
        }

        do {
            let asset = chainAsset.asset
            let assetMapper = CustomAssetMapper(type: asset.type, typeExtras: asset.typeExtras)
            let historyAssetId = try assetMapper.historyAssetId()

            // we support only transfers and swaps for non utility assets

            let mappedFilter = asset.isUtility ? filter : [.transfers, .swaps]
            return SubqueryHistoryOperationFactory(
                url: url,
                filter: mappedFilter,
                assetId: historyAssetId,
                hasPoolStaking: asset.hasPoolStaking,
                hasSwaps: chainAsset.chain.hasSwaps,
                chainFormat: chainAsset.chain.chainFormat
            )
        } catch {
            return nil
        }
    }

    func createEtherscanFactoryForContractAsset(
        for chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> WalletRemoteHistoryFactoryProtocol? {
        let optApi = chainAsset.chain.externalApis?.history()?.first { option in
            option.serviceType == AssetHistoryServiceType.etherscan.rawValue &&
                option.parameters?.assetType?.stringValue == chainAsset.asset.type
        }

        guard filter.contains(.transfers), let url = optApi?.url else {
            return nil
        }

        guard let contractAddress = chainAsset.asset.evmContractAddress else {
            return nil
        }

        return EtherscanERC20OperationFactory(
            contractAddress: contractAddress,
            chainFormat: chainAsset.chain.chainFormat,
            baseUrl: url,
            chainId: chainAsset.chain.chainId
        )
    }

    func createEtherscanFactoryForNativeAsset(
        for chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> WalletRemoteHistoryFactoryProtocol? {
        let optApi = chainAsset.chain.externalApis?.history()?.first { option in
            option.serviceType == AssetHistoryServiceType.etherscan.rawValue
        }

        guard let url = optApi?.url else {
            return nil
        }

        return EtherscanNativeOperationFactory(
            filter: filter,
            chainFormat: chainAsset.chain.chainFormat,
            baseUrl: url,
            chainId: chainAsset.chain.chainId
        )
    }
}

extension AssetHistoryFacade: AssetHistoryFactoryFacadeProtocol {
    func createOperationFactory(
        for chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> WalletRemoteHistoryFactoryProtocol? {
        if chainAsset.asset.isEvmNative {
            return createEtherscanFactoryForNativeAsset(for: chainAsset, filter: filter)
        } else if chainAsset.asset.isEvmAsset {
            return createEtherscanFactoryForContractAsset(for: chainAsset, filter: filter)
        } else {
            return createSubqueryFactory(for: chainAsset, filter: filter)
        }
    }
}
