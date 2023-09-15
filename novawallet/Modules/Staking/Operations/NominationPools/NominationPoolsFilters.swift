protocol NominationPoolsFilterProtocol {
    func apply(for pool: NominationPools.BondedPool) throws -> Bool
}

final class SpareNominationPoolsFilter: NominationPoolsFilterProtocol {
    let maxMembersPerPoolClosure: () throws -> UInt32?

    init(maxMembersPerPoolClosure: @escaping () throws -> UInt32?) {
        self.maxMembersPerPoolClosure = maxMembersPerPoolClosure
    }

    func apply(for pool: NominationPools.BondedPool) throws -> Bool {
        let maxMembersPerPool = try maxMembersPerPoolClosure()
        return pool.checkPoolSpare(for: maxMembersPerPool)
    }
}
