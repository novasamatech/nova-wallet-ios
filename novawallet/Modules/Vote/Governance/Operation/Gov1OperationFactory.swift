import Foundation
import RobinHood
import BigInt
import SubstrateSdk

final class Gov1OperationFactory {

}

extension Gov1OperationFactory: ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(from connection: JSONRPCEngine, runtimeProvider: RuntimeProviderProtocol) -> CompoundOperationWrapper<[ReferendumLocal]> {
        <#code#>
    }

    func fetchAccountVotesWrapper(for accountId: AccountId, from connection: JSONRPCEngine, runtimeProvider: RuntimeProviderProtocol, blockHash: Data?) -> CompoundOperationWrapper<ReferendumAccountVotingDistribution> {
        <#code#>
    }

    func fetchVotersWrapper(for referendumIndex: ReferendumIdLocal, from connection: JSONRPCEngine, runtimeProvider: RuntimeProviderProtocol) -> CompoundOperationWrapper<[ReferendumVoterLocal]> {
        <#code#>
    }


}
