import Foundation
@testable import novawallet
import Operation_iOS

final class MockPreferredValidatorsProvider {
    let store: PreferredValidatorsProvider.Store
    
    init(store: PreferredValidatorsProvider.Store = [:]) {
        self.store = store
    }
}

extension MockPreferredValidatorsProvider: PreferredValidatorsProviding {
    func createPreferredValidatorsWrapper(for chain: ChainModel) -> CompoundOperationWrapper<[AccountId]> {
        do {
            let accountIds = try store[chain.chainId]?.compactMap { try $0.toAccountId(using: chain.chainFormat) }
            
            return CompoundOperationWrapper.createWithResult(accountIds ?? [])
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
