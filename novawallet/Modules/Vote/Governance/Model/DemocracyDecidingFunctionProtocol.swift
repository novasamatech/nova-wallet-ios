import Foundation
import BigInt

protocol DemocracyDecidingFunctionProtocol {
    var thresholdType: Democracy.VoteThreshold { get }
    func calculateThreshold(
        for ayes: BigUInt,
        nays: BigUInt,
        turnout: BigUInt,
        electorate: BigUInt
    ) -> Decimal?
}

final class Gov1DecidingFunction {
    let thresholdType: Democracy.VoteThreshold

    init(thresholdType: Democracy.VoteThreshold) {
        self.thresholdType = thresholdType
    }

    private func calculateSupermajorityApprove(turnout: BigUInt, electorate: BigUInt) -> Decimal? {
        guard
            let turnoutSqrt = Decimal(turnout.squareRoot()),
            let electorateSqrt = Decimal(electorate.squareRoot()) else {
            return nil
        }

        guard electorateSqrt + turnoutSqrt > 0 else {
            return nil
        }

        return electorateSqrt / (electorateSqrt + turnoutSqrt)
    }

    private func calculateSupermajorityAgainst(turnout: BigUInt, electorate: BigUInt) -> Decimal? {
        guard
            let turnoutSqrt = Decimal(turnout.squareRoot()),
            let electorateSqrt = Decimal(electorate.squareRoot()) else {
            return nil
        }

        guard electorateSqrt + turnoutSqrt > 0 else {
            return nil
        }

        return turnoutSqrt / (electorateSqrt + turnoutSqrt)
    }
}

extension Gov1DecidingFunction: DemocracyDecidingFunctionProtocol {
    func calculateThreshold(
        for ayes: BigUInt,
        nays: BigUInt,
        turnout: BigUInt,
        electorate: BigUInt
    ) -> Decimal? {
        switch thresholdType {
        case .superMajorityApprove:
            return calculateSupermajorityApprove(turnout: turnout, electorate: electorate)
        case .superMajorityAgainst:
            return calculateSupermajorityAgainst(turnout: turnout, electorate: electorate)
        case .simpleMajority:
            return 0.5
        case .unknown:
            return nil
        }
    }
}
