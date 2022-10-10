import Foundation
import SubstrateSdk
import RobinHood

protocol ReferendumsOperationFactoryProtocol {
    func fetchAllReferendumsWrapper(
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[ReferendumLocal]>

    func fetchAccountVotes(
        for accountId: AccountId,
        from connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<[Referenda.ReferendumIndex: ReferendumAccountVoteLocal]>
}
