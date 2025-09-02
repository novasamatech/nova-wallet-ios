import Foundation

protocol AvailableBalanceMapping {
    func availableBalance(from assetBalance: AssetBalance) -> Balance
}

extension AvailableBalanceMapping {
    func mapAvailableBalance(from assetBalance: AssetBalance?) -> Balance? {
        assetBalance.map { availableBalance(from: $0) }
    }

    func availableBalanceElseZero(from assetBalance: AssetBalance?) -> Balance {
        mapAvailableBalance(from: assetBalance) ?? 0
    }
}

struct AvailableBalanceSliceMapper {
    let balanceSlice: KeyPath<AssetBalance, Balance>
}

extension AvailableBalanceSliceMapper: AvailableBalanceMapping {
    func availableBalance(from assetBalance: AssetBalance) -> Balance {
        assetBalance[keyPath: balanceSlice]
    }
}
