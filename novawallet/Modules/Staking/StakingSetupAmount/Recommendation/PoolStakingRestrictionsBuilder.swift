import Foundation
import RobinHood
import BigInt

final class PoolStakingRestrictionsBuilder {
    let chainAsset: ChainAsset
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol

    weak var delegate: RelaychainStakingRestrictionsBuilderDelegate?

    private var minJoinBondProvider: AnyDataProvider<DecodedBigUInt>?

    init(
        chainAsset: ChainAsset,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
    }

    func sendRestrictions(for minJoinBond: BigUInt?) {
        let restrictions = RelaychainStakingRestrictions(
            minJoinStake: minJoinBond,
            minRewardableStake: minJoinBond,
            allowsNewStakers: true
        )

        delegate?.restrictionsBuilder(self, didPrepare: restrictions)
    }
}

extension PoolStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding {
    func start() {
        minJoinBondProvider = subscribeMinJoinBond(for: chainAsset.chain.chainId)
    }

    func stop() {
        minJoinBondProvider = nil
    }
}

extension PoolStakingRestrictionsBuilder: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleMinJoinBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(minJoinBond):
            sendRestrictions(for: minJoinBond)
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }
}
