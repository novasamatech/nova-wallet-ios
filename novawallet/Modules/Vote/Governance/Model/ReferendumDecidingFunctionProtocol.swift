import Foundation

protocol ReferendumDecidingFunctionProtocol {
    var curve: Referenda.Curve { get }
    func calculateThreshold(for block: BlockNumber) -> Decimal?
    func calculateThreshold(for delay: Decimal) -> Decimal?
}

extension ReferendumDecidingFunctionProtocol {
    // the function returns smallest x for which given treshold value is passing
    // the function returns nil either if there is no x for given treshold
    // or calculation error occured
    func delay(for yVal: Decimal) -> Decimal? {
        switch curve {
        case let .linearDecreasing(params):
            calculateLinearCurveDelay(for: yVal, with: params)
        case let .steppedDecreasing(params):
            calculateSteppedDecreasingCurveDelay(for: yVal, with: params)
        case let .reciprocal(params):
            calculateReciprocalCurveDelay(for: yVal, with: params)
        case .unknown:
            nil
        }
    }

    private func calculateLinearCurveDelay(
        for yVal: Decimal,
        with params: Referenda.LinearDecreasingCurve
    ) -> Decimal? {
        guard
            let length = Decimal.fromSubstratePerbill(value: params.length),
            length > 0.0,
            let ceil = Decimal.fromSubstratePerbill(value: params.ceil),
            let floor = Decimal.fromSubstratePerbill(value: params.floor) else {
            return nil
        }

        if yVal < floor {
            return nil
        } else if yVal > ceil {
            return .zero
        } else {
            let numerator = (ceil - yVal) as NSDecimalNumber
            let denominator = (ceil - floor) as NSDecimalNumber
            let divisionResult = numerator.dividing(
                by: denominator,
                withBehavior: Decimal.Rounding.up(scale: NSDecimalNoScale)
            ).decimalValue

            return divisionResult * length
        }
    }

    private func calculateSteppedDecreasingCurveDelay(
        for yVal: Decimal,
        with params: Referenda.SteppedDecreasingCurve
    ) -> Decimal? {
        guard
            let begin = Decimal.fromSubstratePerbill(value: params.begin),
            let end = Decimal.fromSubstratePerbill(value: params.end),
            let period = Decimal.fromSubstratePerbill(value: params.period),
            period > 0,
            let step = Decimal.fromSubstratePerbill(value: params.step) else {
            return nil
        }

        if yVal < end {
            return nil
        } else {
            let steps = (begin - min(yVal, begin) + step.lessEpsilon()).divideToIntegralValue(by: step)
            return period * steps
        }
    }

    private func calculateReciprocalCurveDelay(
        for yVal: Decimal,
        with params: Referenda.ReciprocalCurve
    ) -> Decimal? {
        let factor = Decimal.fromFixedI64(value: params.factor) as NSDecimalNumber
        let xOffset = Decimal.fromFixedI64(value: params.xOffset)
        let yOffset = Decimal.fromFixedI64(value: params.yOffset)

        let yTerm = yVal - yOffset

        guard yTerm > 0 else {
            return nil
        }

        let term = factor.dividing(
            by: yTerm as NSDecimalNumber,
            withBehavior: Decimal.Rounding.up(scale: NSDecimalNoScale)
        )

        let result = max(0, min(term.decimalValue - xOffset, 1))

        return result
    }
}

struct Gov2LocalDecidingFunction: ReferendumDecidingFunctionProtocol {
    let curve: Referenda.Curve
    let startBlock: BlockNumber?
    let period: Moment

    private func calculateLinearDecreasing(from xPoint: Decimal, params: Referenda.LinearDecreasingCurve) -> Decimal? {
        guard
            let length = Decimal.fromSubstratePerbill(value: params.length),
            length > 0.0,
            let ceil = Decimal.fromSubstratePerbill(value: params.ceil),
            let floor = Decimal.fromSubstratePerbill(value: params.floor)
        else {
            return nil
        }

        let result = ceil
            - (ceil - floor)
            * (min(xPoint, length) as NSDecimalNumber)
            .dividing(
                by: length as NSDecimalNumber,
                withBehavior: Decimal.Rounding.down(scale: NSDecimalNoScale)
            ).decimalValue

        return result
    }

    private func calculateReciprocal(from xPoint: Decimal, params: Referenda.ReciprocalCurve) -> Decimal? {
        let factor = Decimal.fromFixedI64(value: params.factor) as NSDecimalNumber
        let xOffset = Decimal.fromFixedI64(value: params.xOffset)
        let yOffset = Decimal.fromFixedI64(value: params.yOffset)

        let xAdd = xPoint + xOffset

        guard xAdd > 0 else {
            return nil
        }

        let result = factor.dividing(
            by: xAdd as NSDecimalNumber,
            withBehavior: Decimal.Rounding.down(scale: NSDecimalNoScale)
        ).decimalValue + yOffset

        return max(0, min(result, 1))
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
        let yPoint = begin - min(periodIndex * step, begin)

        return max(yPoint, end)
    }
}

extension Gov2LocalDecidingFunction {
    func calculateThreshold(for block: BlockNumber) -> Decimal? {
        let xPoint: Decimal

        let startBlock = self.startBlock ?? block

        if block < startBlock {
            xPoint = 0
        } else if block > startBlock + period {
            xPoint = 1
        } else {
            xPoint = Decimal(block - startBlock) / Decimal(period)
        }

        return threshold(for: xPoint)
    }

    func calculateThreshold(for delay: Decimal) -> Decimal? {
        threshold(for: delay)
    }

    private func threshold(for xPoint: Decimal) -> Decimal? {
        switch curve {
        case let .linearDecreasing(params):
            calculateLinearDecreasing(from: xPoint, params: params)
        case let .reciprocal(params):
            calculateReciprocal(from: xPoint, params: params)
        case let .steppedDecreasing(params):
            calculateSteppedDecreasing(from: xPoint, params: params)
        case .unknown:
            nil
        }
    }
}
