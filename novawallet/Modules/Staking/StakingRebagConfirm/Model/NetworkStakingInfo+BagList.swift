import BigInt

extension NetworkStakingInfo {
    func searchBounds(for node: BagList.Node, totalIssuance: BigUInt) -> BagListBounds? {
        guard let votersInfo = votersInfo, let currentBagListIndex = votersInfo
            .bagsThresholds
            .firstIndex(where: { $0 == node.bagUpper }) else {
            return nil
        }

        let lowerBoundScore = votersInfo.bagsThresholds[safe: currentBagListIndex - 1] ?? 0
        let upperBoundScore = node.bagUpper

        let lowerBound = BagList.stake(score: lowerBoundScore, totalIssuance: totalIssuance)
        let upperBound = BagList.stake(score: upperBoundScore, totalIssuance: totalIssuance)

        return .init(lower: lowerBound, upper: upperBound)
    }

    func searchBounds(ledgerInfo: Staking.Ledger, totalIssuance: BigUInt) -> BagListBounds? {
        guard let votersInfo = votersInfo else {
            return nil
        }

        let score = BagList.scoreOf(
            stake: ledgerInfo.active,
            totalIssuance: totalIssuance
        )

        let lowerBoundScore: BagList.Score
        let upperBoundScore: BagList.Score

        if let targetTresholdIndex = votersInfo.bagsThresholds.firstIndex(where: { $0 >= score }) {
            lowerBoundScore = votersInfo.bagsThresholds[safe: targetTresholdIndex - 1] ?? 0
            upperBoundScore = votersInfo.bagsThresholds[targetTresholdIndex]
        } else {
            lowerBoundScore = votersInfo.bagsThresholds.last ?? 0
            upperBoundScore = BagList.maxScore
        }

        let lowerBound = BagList.stake(score: lowerBoundScore, totalIssuance: totalIssuance)
        let upperBound = BagList.stake(score: upperBoundScore, totalIssuance: totalIssuance)

        return .init(lower: lowerBound, upper: upperBound)
    }
}
