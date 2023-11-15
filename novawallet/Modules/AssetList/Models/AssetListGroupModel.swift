import Foundation
import RobinHood
import BigInt

struct AssetListGroupModel: Identifiable {
    var identifier: String { chain.chainId }

    let chain: ChainModel
    let chainValue: Decimal
    let chainAmount: BigUInt

    init(chain: ChainModel, chainValue: Decimal, chainAmount: BigUInt) {
        self.chain = chain
        self.chainValue = chainValue
        self.chainAmount = chainAmount
    }
}
