import Foundation

extension AssetListModelHelpers {
    static var assetSortingBlockDefaultByChain: (
        AssetListAssetModel,
        AssetListAssetModel
    ) -> Bool = { lhs, rhs in
        if let result = AssetListAssetModelCompator.by(\.totalAmountDecimal, lhs, rhs) {
            result
        } else {
            ChainModelCompator.defaultComparator(
                chain1: lhs.chainAssetModel.chain,
                chain2: rhs.chainAssetModel.chain
            )
        }
    }

    static var assetSortingBlockDefaultByLexical: (
        AssetListAssetModel,
        AssetListAssetModel
    ) -> Bool = { lhs, rhs in
        if let result = AssetListAssetModelCompator.by(\.totalAmountDecimal, lhs, rhs) {
            result
        } else {
            lhs.chainAssetModel.asset.symbol.lexicographicallyPrecedes(
                rhs.chainAssetModel.asset.symbol
            )
        }
    }

    static var assetListAssetGroupSortingBlock: (
        AssetListAssetGroupModel,
        AssetListAssetGroupModel
    ) -> Bool = { lhs, rhs in
        if let result = AssetListGroupModelComparator.by(\.value, lhs, rhs) {
            result
        } else if let result = AssetListGroupModelComparator.by(\.amount, lhs, rhs) {
            result
        } else {
            AssetListGroupModelComparator.defaultComparator(
                lhs: lhs,
                rhs: rhs
            )
        }
    }

    static var assetListChainGroupSortingBlock: (
        AssetListChainGroupModel,
        AssetListChainGroupModel
    ) -> Bool = { lhs, rhs in
        if let result = AssetListGroupModelComparator.by(\.value, lhs, rhs) {
            result
        } else if let result = AssetListGroupModelComparator.by(\.amount, lhs, rhs) {
            result
        } else {
            ChainModelCompator.defaultComparator(
                chain1: lhs.chain,
                chain2: rhs.chain
            )
        }
    }

    static var nftSortingBlock: (
        NftModel, NftModel
    ) -> Bool = { model1, model2 in
        guard let createdAt1 = model1.createdAt, let createdAt2 = model2.createdAt else {
            return true
        }

        return createdAt1.compare(createdAt2) == .orderedDescending
    }
}
