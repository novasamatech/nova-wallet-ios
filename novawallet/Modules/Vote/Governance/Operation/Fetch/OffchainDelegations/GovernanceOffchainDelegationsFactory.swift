import Foundation
import RobinHood

protocol GovernanceOffchainDelegationsFactoryProtocol {
    func createDelegationsFetchWrapper(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<[GovernanceOffchainDelegation]>
}
