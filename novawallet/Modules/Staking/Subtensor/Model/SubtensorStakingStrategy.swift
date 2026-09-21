import Foundation

struct SubtensorStakingStrategy: Equatable {
    enum Kind: CaseIterable, Equatable {
        case steady
        case balanced
        case higherUpside
    }

    enum Range: Equatable {
        case fixed
        case percentage(lower: Decimal, upper: Decimal)
    }

    let kind: Kind
    let annualReturn: Decimal
    let range: Range
    let chartValues: [Double]
}
