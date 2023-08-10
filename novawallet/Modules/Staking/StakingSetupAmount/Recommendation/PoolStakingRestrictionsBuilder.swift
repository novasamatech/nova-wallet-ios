import Foundation
import RobinHood
import BigInt

final class PoolStakingRestrictionsBuilder {
    let chainAsset: ChainAsset
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol

    weak var delegate: RelaychainStakingRestrictionsBuilderDelegate?

    private var minJoinBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var maxPoolMembersProvider: AnyDataProvider<DecodedU32>?
    private var counterForPoolMembersProvider: AnyDataProvider<DecodedU32>?

    private var minJoinBond: BigUInt?
    private var maxPoolMembers: UInt32?
    private var counterForPoolMembers: UInt32?

    init(
        chainAsset: ChainAsset,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
    }

    func sendRestrictions() {
        let allowsNewStakers: Bool

        if let maxPoolMembers = maxPoolMembers, let counterForPoolMembers = counterForPoolMembers {
            allowsNewStakers = counterForPoolMembers < maxPoolMembers
        } else {
            allowsNewStakers = true
        }

        let restrictions = RelaychainStakingRestrictions(
            minJoinStake: minJoinBond,
            minRewardableStake: minJoinBond,
            allowsNewStakers: allowsNewStakers
        )

        delegate?.restrictionsBuilder(self, didPrepare: restrictions)
    }
}

extension PoolStakingRestrictionsBuilder: RelaychainStakingRestrictionsBuilding {
    func start() {
        minJoinBondProvider = subscribeMinJoinBond(for: chainAsset.chain.chainId)
        maxPoolMembersProvider = subscribeMaxPoolMembers(for: chainAsset.chain.chainId)
        counterForPoolMembersProvider = subscribeCounterForPoolMembers(for: chainAsset.chain.chainId)
    }

    func stop() {
        minJoinBondProvider = nil
        maxPoolMembersProvider = nil
        counterForPoolMembersProvider = nil
    }
}

extension PoolStakingRestrictionsBuilder: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleMinJoinBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(minJoinBond):
            self.minJoinBond = minJoinBond
            sendRestrictions()
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }

    func handleMaxPoolMembers(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(maxPoolMembers):
            self.maxPoolMembers = maxPoolMembers
            sendRestrictions()
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }

    func handleCounterForPoolMembers(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(counterForPoolMembers):
            self.counterForPoolMembers = counterForPoolMembers
            sendRestrictions()
        case let .failure(error):
            delegate?.restrictionsBuilder(self, didReceive: error)
        }
    }
}
