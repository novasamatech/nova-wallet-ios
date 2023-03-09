import BigInt

extension NetworkStakingInfo {
    func searchBounds(for node: BagList.Node) -> BagListBounds? {
        guard let votersInfo = votersInfo, let currentBagListIndex = votersInfo
            .bagsThresholds
            .firstIndex(where: { $0 == node.bagUpper }) else {
            return nil
        }

        let lowerBound = votersInfo.bagsThresholds[safe: currentBagListIndex - 1] ?? 0
        return .init(lower: lowerBound, upper: node.bagUpper)
    }

    func searchBounds(ledgerInfo: StakingLedger, totalIssuance: BigUInt) -> BagListBounds? {
        guard let votersInfo = votersInfo else {
            return nil
        }

        let score = BagList.scoreOf(
            stake: ledgerInfo.active,
            totalIssuance: totalIssuance
        )

        let lowerBound: BigUInt
        let upperBound: BigUInt

        if let targetTresholdIndex = votersInfo.bagsThresholds.firstIndex(where: { $0 > score }) {
            lowerBound = votersInfo.bagsThresholds[safe: targetTresholdIndex - 1] ?? 0
            upperBound = votersInfo.bagsThresholds[targetTresholdIndex]
        } else {
            lowerBound = votersInfo.bagsThresholds.last ?? 0
            upperBound = BigUInt(UInt64.max)
        }

        return .init(lower: lowerBound, upper: upperBound)
    }
}
