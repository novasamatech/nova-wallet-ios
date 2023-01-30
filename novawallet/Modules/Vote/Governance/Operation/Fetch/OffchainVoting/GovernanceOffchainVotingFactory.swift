import Foundation
import RobinHood

protocol GovernanceOffchainVotingFactoryProtocol {
    func createVotingFetchOperation(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainVoting>
}
