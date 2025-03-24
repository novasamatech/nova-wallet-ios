import Foundation

protocol GovernanceBalanceCalculating {
    func availableBalance(from assetBalance: AssetBalance) -> Balance
}

extension GovernanceBalanceCalculating {
    func mapAvailableBalance(from assetBalance: AssetBalance?) -> Balance? {
        assetBalance.map { availableBalance(from: $0) }
    }

    func availableBalanceElseZero(from assetBalance: AssetBalance?) -> Balance {
        mapAvailableBalance(from: assetBalance) ?? 0
    }
}

struct GovernanceBalanceCalculator {
    let governanceType: GovernanceType
}

extension GovernanceBalanceCalculator: GovernanceBalanceCalculating {
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
    func createCalculator(for governanceType: GovernanceType) -> GovernanceBalanceCalculating
}

final class GovBalanceCalculatorFactory {}

extension GovBalanceCalculatorFactory: GovBalanceCalculatorFactoryProtocol {
    func createCalculator(for governanceType: GovernanceType) -> GovernanceBalanceCalculating {
        GovernanceBalanceCalculator(governanceType: governanceType)
    }
}
