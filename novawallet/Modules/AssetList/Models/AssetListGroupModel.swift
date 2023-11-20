import Foundation
import RobinHood
import BigInt

struct AssetListGroupModel: Identifiable {
    var identifier: String { chain.chainId }

    let chain: ChainModel
    let chainValue: Decimal
    let chainAmount: Decimal

    init(chain: ChainModel, chainValue: Decimal, chainAmount: Decimal) {
        self.chain = chain
        self.chainValue = chainValue
        self.chainAmount = chainAmount
    }
}
