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

    private func calculateSupermajorityApprove(
        for ayes: BigUInt,
        nays: BigUInt,
        turnout: BigUInt,
        electorate: BigUInt
    ) -> Decimal? {
        guard
            let totalDecimal = Decimal(ayes + nays),
            let naysDecimal = Decimal(nays),
            let turnoutSqrt = Decimal(turnout.squareRoot()),
            let electorateSqrt = Decimal(electorate.squareRoot()) else {
            return nil
        }

        guard totalDecimal > 0, turnoutSqrt > 0 else {
            return nil
        }

        let naysFraction = naysDecimal / totalDecimal

        return naysFraction * (electorateSqrt / turnoutSqrt)
    }

    private func calculateSupermajorityAgainst(
        for ayes: BigUInt,
        nays: BigUInt,
        turnout: BigUInt,
        electorate: BigUInt
    ) -> Decimal? {
        guard
            let totalDecimal = Decimal(ayes + nays),
            let naysDecimal = Decimal(nays),
            let turnoutSqrt = Decimal(turnout.squareRoot()),
            let electorateSqrt = Decimal(electorate.squareRoot()) else {
            return nil
        }

        guard totalDecimal > 0, electorateSqrt > 0 else {
            return nil
        }

        let naysFraction = naysDecimal / totalDecimal

        return naysFraction * (turnoutSqrt / electorateSqrt)
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
            return calculateSupermajorityApprove(
                for: ayes,
                nays: nays,
                turnout: turnout,
                electorate: electorate
            )
        case .superMajorityAgainst:
            return calculateSupermajorityAgainst(
                for: ayes,
                nays: nays,
                turnout: turnout,
                electorate: electorate
            )
        case .simpleMajority:
            return 0.5
        case .unknown:
            return nil
        }
    }
}
