import Foundation
import BigInt

struct SubtensorSubnetParameters {
    let ref: SubtensorSubnetRef
    let validators: Int?
    let age: TimeInterval?
    let emission: Decimal?

    init(
        ref: SubtensorSubnetRef,
        rows: [SubtensorPallet.DynamicInfo?]?,
        blockNumber: BlockNumber?,
        permits: [Bool]?,
        emissionEnabled: Bool?,
        blockTime: BlockTime?
    ) {
        self.ref = ref
        validators = permits?.filter { $0 }.count
        age = Self.age(registeredAt: ref.registeredAt, head: blockNumber, blockTime: blockTime)
        emission = Self.emission(ref: ref, rows: rows, enabled: emissionEnabled)
    }
}

private extension SubtensorSubnetParameters {
    static func age(registeredAt: UInt64, head: BlockNumber?, blockTime: BlockTime?) -> TimeInterval? {
        guard let head, let blockTime, blockTime > 0, registeredAt > 0, registeredAt <= UInt64(head) else {
            return nil
        }
        let elapsed = (UInt64(head) - registeredAt).multipliedReportingOverflow(by: UInt64(blockTime))
        guard !elapsed.overflow else { return nil }
        return TimeInterval(elapsed.partialValue) / 1000
    }

    static func emission(
        ref: SubtensorSubnetRef,
        rows: [SubtensorPallet.DynamicInfo?]?,
        enabled: Bool?
    ) -> Decimal? {
        let population = rows?.compactMap { $0 } ?? []
        let matches = population.filter { $0.netuid == ref.netuid }
        guard matches.count == 1, let subnet = matches.first, subnet.networkRegisteredAt == ref.registeredAt,
              let enabled else {
            return nil
        }
        guard enabled else { return 0 }
        guard population.count == rows?.count, Set(population.map(\.netuid)).count == population.count else {
            return nil
        }
        let total = population.reduce(Balance(0)) { $0 + $1.taoInEmission }
        guard total > 0 else { return nil }
        return BigRational(numerator: subnet.taoInEmission, denominator: total).decimalValue
    }
}
