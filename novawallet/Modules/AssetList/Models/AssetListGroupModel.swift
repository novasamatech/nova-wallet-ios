import Foundation
import Operation_iOS
import BigInt

protocol GroupAmountContainable {
    var value: Decimal { get }
    var amount: Decimal { get }
}

struct AssetListChainGroupModel: Identifiable, GroupAmountContainable {
    var identifier: String { chain.chainId }

    let chain: ChainModel
    let value: Decimal
    let amount: Decimal

    init(chain: ChainModel, value: Decimal, amount: Decimal) {
        self.chain = chain
        self.value = value
        self.amount = amount
    }
}

struct AssetListAssetGroupModel: Identifiable, GroupAmountContainable {
    var identifier: String { chainAsset.identifier }

    let chainAsset: ChainAsset
    let value: Decimal
    let amount: Decimal

    init(chainAsset: ChainAsset, value: Decimal, amount: Decimal) {
        self.chainAsset = chainAsset
        self.value = value
        self.amount = amount
    }
}
