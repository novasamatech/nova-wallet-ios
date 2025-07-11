import Foundation

final class DelegatedSignValidationSharedData {
    let accounts: InMemoryCache<AccountId, AssetBalance>
    var paidFee: ExtrinsicFeeProtocol?

    init() {
        accounts = InMemoryCache<AccountId, AssetBalance>()
    }
}
