import Foundation

struct GovernanceBalanceCalculator {
    let governanceType: GovernanceType
}

extension GovernanceBalanceCalculator: AvailableBalanceMapping {
    func availableBalance(from assetBalance: AssetBalance) -> Balance {
        switch governanceType {
        case .governanceV1:
            return assetBalance.freeInPlank
        case .governanceV2:
            return assetBalance.totalInPlank
        }
    }
}

protocol GovBalanceCalculatorFactoryProtocol {
    func createCalculator(for governanceType: GovernanceType) -> AvailableBalanceMapping
}

final class GovBalanceCalculatorFactory {}

extension GovBalanceCalculatorFactory: GovBalanceCalculatorFactoryProtocol {
    func createCalculator(for governanceType: GovernanceType) -> AvailableBalanceMapping {
        GovernanceBalanceCalculator(governanceType: governanceType)
    }
}
