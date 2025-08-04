import Foundation

final class DelegatedSignValidationSharedData {
    let accounts: InMemoryCache<AccountId, AssetBalance>
    var paidFees: InMemoryCache<AccountId, Balance>

    init() {
        accounts = InMemoryCache<AccountId, AssetBalance>()
        paidFees = InMemoryCache<AccountId, Balance>()
    }
}
