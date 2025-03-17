import Foundation

struct PayCardTopupModel {
    let chainAsset: ChainAsset
    let amount: Decimal
    let recipientAddress: AccountAddress
}
