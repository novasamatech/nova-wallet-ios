import Foundation
import BigInt

struct SubtensorSubnetParameters {
    let ref: SubtensorSubnetRef
    let blockHash: BlockHash
    let blockNumber: BlockNumber?
    let subnet: SubtensorStakingPallet.DynamicInfo?
    let alphaPrice: Balance?
    let validators: Int?
    let age: TimeInterval?
    let emission: Decimal?
    let isPopulationComplete: Bool

    var poolSplit: Decimal? {
        guard let subnet, subnet.taoIn + subnet.alphaIn > 0 else { return nil }
        return BigRational(numerator: subnet.taoIn, denominator: subnet.taoIn + subnet.alphaIn).decimalValue
    }

    init(
        ref: SubtensorSubnetRef,
        blockHash: BlockHash,
        rows: [SubtensorStakingPallet.DynamicInfo?]?,
        prices: [SubtensorStakingPallet.SubnetPrice]?,
        blockNumber: BlockNumber?,
        permits: [Bool]?,
        emissionEnabled: Bool?,
        blockTime: BlockTime?
    ) {
        self.ref = ref
        self.blockHash = blockHash
        self.blockNumber = blockNumber
        let population = rows?.compactMap { $0 } ?? []
        isPopulationComplete = rows != nil && population.count == rows?.count &&
            Set(population.map(\.netuid)).count == population.count
        let matches = population.filter { $0.netuid == ref.netuid }
        subnet = matches.count == 1 && matches.first?.networkRegisteredAt == ref.registeredAt ? matches.first : nil
        let matchingPrices = prices?.filter { $0.netuid == ref.netuid } ?? []
        alphaPrice = subnet != nil && matchingPrices.count == 1 ? matchingPrices.first?.price : nil
        validators = subnet != nil ? permits?.filter { $0 }.count : nil
        age = subnet.flatMap { Self.age(registeredAt: $0.networkRegisteredAt, head: blockNumber, blockTime: blockTime) }
        emission = Self.emission(
            subnet: subnet, population: population, isComplete: isPopulationComplete, enabled: emissionEnabled
        )
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
        subnet: SubtensorStakingPallet.DynamicInfo?,
        population: [SubtensorStakingPallet.DynamicInfo],
        isComplete: Bool,
        enabled: Bool?
    ) -> Decimal? {
        guard let subnet, let enabled else { return nil }
        guard enabled else { return 0 }
        guard isComplete else { return nil }
        let total = population.reduce(Balance(0)) { $0 + $1.taoInEmission }
        guard total > 0 else { return nil }
        return BigRational(numerator: subnet.taoInEmission, denominator: total).decimalValue
    }
}
