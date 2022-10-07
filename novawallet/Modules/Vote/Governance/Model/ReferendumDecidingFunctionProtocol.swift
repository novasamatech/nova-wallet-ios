import Foundation

protocol ReferendumDecidingFunctionProtocol {
    func calculateThreshold(for block: BlockNumber) -> Decimal?
}

struct Gov2LocalDecidingFunction: ReferendumDecidingFunctionProtocol {
    let curve: Referenda.Curve
    let startBlock: BlockNumber
    let period: Moment

    private func calculateLinearDecreasing(from xPoint: Decimal, params: Referenda.LinearDecreasingCurve) -> Decimal? {
        guard
            let length = Decimal.fromSubstratePerbill(value: params.length),
            length > 0.0,
            let ceil = Decimal.fromSubstratePerbill(value: params.ceil),
            let floor = Decimal.fromSubstratePerbill(value: params.floor) else {
            return nil
        }

        return ceil - (ceil - floor) * min(xPoint, length) / length
    }

    private func calculateReciprocal(from xPoint: Decimal, params: Referenda.ReciprocalCurve) -> Decimal? {
        let factor = Decimal.fromFixedI64(value: params.factor)
        let xOffset = Decimal.fromFixedI64(value: params.xOffset)
        let yOffset = Decimal.fromFixedI64(value: params.yOffset)

        let xAdd = xPoint + xOffset

        guard xAdd > 0 else {
            return nil
        }

        return factor / xAdd + yOffset
    }

    private func calculateSteppedDecreasing(
        from xPoint: Decimal,
        params: Referenda.SteppedDecreasingCurve
    ) -> Decimal? {
        guard
            let begin = Decimal.fromSubstratePerbill(value: params.begin),
            let end = Decimal.fromSubstratePerbill(value: params.end),
            let period = Decimal.fromSubstratePerbill(value: params.period),
            period > 0,
            let step = Decimal.fromSubstratePerbill(value: params.step) else {
            return nil
        }

        let periodIndex = (xPoint / period).floor()
        let yPoint = min(begin - periodIndex * step, begin)

        return max(yPoint, end)
    }
}

extension Gov2LocalDecidingFunction {
    func calculateThreshold(for block: BlockNumber) -> Decimal? {
        let xPoint: Decimal

        if block < startBlock {
            xPoint = 0
        } else if block > startBlock + period {
            xPoint = 1
        } else {
            xPoint = Decimal(block - startBlock) / Decimal(period)
        }

        switch curve {
        case let .linearDecreasing(params):
            return calculateLinearDecreasing(from: xPoint, params: params)
        case let .reciprocal(params):
            return calculateReciprocal(from: xPoint, params: params)
        case let .steppedDecreasing(params):
            return calculateSteppedDecreasing(from: xPoint, params: params)
        case .unknown:
            return nil
        }
    }
}
