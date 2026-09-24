import Foundation

enum AssetCategoryClassifier {
    private static let native: Set<String> = [
        "DOT", "KSM", "ETH", "BTC", "BNB", "AVAX", "MATIC",
        "SOL", "FTM", "GLMR", "MOVR", "ASTR", "ACA", "CFG",
        "HDX", "INTR", "KINT", "PHA", "ZTG", "NODL", "RING",
        "TEER", "TUR", "UNQ", "AZERO"
    ]

    private static let stable: Set<String> = [
        "USDT", "USDC", "DAI", "BUSD", "TUSD", "FRAX", "LUSD",
        "USDP", "GUSD", "USDD", "CRVUSD", "GHO", "PYUSD",
        "AUSD", "IUSD"
    ]

    private static let wrapped: Set<String> = [
        "WETH", "WBTC", "WBNB", "WAVAX", "WMATIC", "WFTM",
        "WGLMR", "WMOVR", "WDOT", "WKSM"
    ]

    static func classify(_ symbol: String) -> AssetCategory {
        let normalized = symbol.uppercased()

        if native.contains(normalized) {
            return .nativeToken
        }

        if stable.contains(normalized) {
            return .stablecoin
        }

        if wrapped.contains(normalized) {
            return .wrappedToken
        }

        if normalized.hasPrefix("W"), native.contains(String(normalized.dropFirst())) {
            return .wrappedToken
        }

        return .other
    }
}
