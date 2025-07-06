import Foundation

final class DelegatedSignValidationSharedData {
    let accounts: InMemoryCache<AccountId, AssetBalance>

    init() {
        accounts = InMemoryCache<AccountId, AssetBalance>()
    }
}
