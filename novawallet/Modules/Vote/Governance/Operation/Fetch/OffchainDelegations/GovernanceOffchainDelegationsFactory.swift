import Foundation
import Operation_iOS

protocol GovernanceOffchainDelegationsFactoryProtocol {
    func createDelegationsFetchWrapper(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<[GovernanceOffchainDelegation]>
}
