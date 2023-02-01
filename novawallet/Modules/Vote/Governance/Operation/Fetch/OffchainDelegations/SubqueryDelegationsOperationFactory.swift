import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class SubqueryDelegationsOperationFactory: SubqueryBaseOperationFactory {
    private func prepareListQuery(for address: AccountAddress) -> String {
        """
        {
           delegations(filter: { delegateId: {equalTo: "\(address)"}}) {
              nodes {
                delegator
                delegation
              }
           }
        }
        """
    }
}

extension SubqueryDelegationsOperationFactory: GovernanceOffchainDelegationsFactoryProtocol {
    func createDelegationsFetchWrapper(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<[GovernanceOffchainDelegation]> {
        let query = prepareListQuery(for: address)

        let operation = createOperation(
            for: query
        ) { (response: SubqueryDelegationsReponse) -> [GovernanceOffchainDelegation] in
            response.delegations.nodes.compactMap { delegation in
                let delegatorConviction = ConvictionVoting.Conviction(
                    subqueryConviction: delegation.delegation.conviction
                )

                guard let delegatorBalance = BigUInt(delegation.delegation.amount) else {
                    return nil
                }

                let delegatorPower = GovernanceOffchainVoting.DelegatorPower(
                    balance: delegatorBalance,
                    conviction: delegatorConviction
                )

                return GovernanceOffchainDelegation(delegator: delegation.delegator, power: delegatorPower)
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
