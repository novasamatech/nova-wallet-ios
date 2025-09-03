import Foundation
import Operation_iOS

typealias DelegatedAccountsByDelegateMapping = [AccountId: [DiscoveredDelegatedAccountProtocol]]

protocol DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegateMapping>
}
