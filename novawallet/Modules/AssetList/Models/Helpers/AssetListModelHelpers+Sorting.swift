import Foundation

extension AssetListModelHelpers {
    static var assetSortingBlockDefaultByChain: (
        AssetListAssetModel,
        AssetListAssetModel
    ) -> Bool = { lhs, rhs in
        if let result = AssetListAssetModelComparator.by(\.totalValue, lhs, rhs) {
            result
        } else if let result = AssetListAssetModelComparator.by(\.totalAmountDecimal, lhs, rhs) {
            result
        } else {
            ChainModelCompator.defaultComparator(
                chain1: lhs.chainAssetModel.chain,
                chain2: rhs.chainAssetModel.chain
            )
        }
    }

    static var assetSortingBlockDefaultByUtility: (
        AssetListAssetModel,
        AssetListAssetModel
    ) -> Bool = { lhs, rhs in
        if let result = AssetListAssetModelComparator.by(\.totalValue, lhs, rhs) {
            result
        } else if let result = AssetListAssetModelComparator.by(\.totalAmountDecimal, lhs, rhs) {
            result
        } else {
            AssetListAssetModelComparator.byChain(
                lhs: lhs,
                rhs: rhs
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

    static var pendingOperationSortingBlock: (
        Multisig.PendingOperation, Multisig.PendingOperation
    ) -> Bool = { _, _ in
        true
    }
}
