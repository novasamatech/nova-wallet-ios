import Foundation
import BigInt

enum EvmFallbackGasLimit {
    static let erc20: BigUInt = 200_000
    static let native: BigUInt = 21000

    static func value(for asset: AssetModel) -> BigUInt {
        let type = asset.type.flatMap { AssetType(rawValue: $0) }

        switch type {
        case .evmAsset:
            return Self.erc20
        case .evmNative:
            return Self.native
        case .none, .statemine, .orml, .ormlHydrationEvm, .equilibrium:
            return 0
        }
    }
}
