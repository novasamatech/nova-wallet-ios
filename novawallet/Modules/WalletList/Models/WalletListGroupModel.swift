import Foundation
import RobinHood

struct WalletListGroupModel: Identifiable {
    var identifier: String { chain.chainId }

    let chain: ChainModel
    let chainValue: Decimal

    init(chain: ChainModel, chainValue: Decimal) {
        self.chain = chain
        self.chainValue = chainValue
    }
}
