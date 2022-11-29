import Foundation

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
        let optApi = chainAsset.chain.externalApi?.history?.first { option in
            option.serviceType == AssetHistoryServiceType.subquery.rawValue &&
                (option.assetType == nil || option.assetType == chainAsset.asset.type)
        }

        guard let url = optApi?.url else {
            return nil
        }

        do {
            let asset = chainAsset.asset
            let assetMapper = CustomAssetMapper(type: asset.type, typeExtras: asset.typeExtras)
            let historyAssetId = try assetMapper.historyAssetId()

            return SubqueryHistoryOperationFactory(
                url: url,
                filter: filter,
                assetId: historyAssetId
            )
        } catch {
            return nil
        }
    }

    func createEtherscanFactory(
        for chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> WalletRemoteHistoryFactoryProtocol? {
        let optApi = chainAsset.chain.externalApi?.history?.first { option in
            option.serviceType == AssetHistoryServiceType.etherscan.rawValue &&
                option.assetType == chainAsset.asset.type
        }

        guard filter.contains(.transfers), let url = optApi?.url else {
            return nil
        }

        guard let contractAddress = chainAsset.asset.typeExtras?.stringValue else {
            return nil
        }

        return EtherscanOperationFactory(contractAddress: contractAddress, url: url)
    }
}

extension AssetHistoryFacade: AssetHistoryFactoryFacadeProtocol {
    func createOperationFactory(
        for chainAsset: ChainAsset,
        filter: WalletHistoryFilter
    ) -> WalletRemoteHistoryFactoryProtocol? {
        if chainAsset.asset.isEvm {
            return createEtherscanFactory(for: chainAsset, filter: filter)
        } else {
            return createSubqueryFactory(for: chainAsset, filter: filter)
        }
    }
}
