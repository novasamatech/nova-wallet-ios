import Foundation
import BigInt

extension FormattedCall {
    struct Transfer {
        let amount: BigUInt
        let account: Account
        let asset: ChainAsset
    }
}
