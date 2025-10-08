import Foundation
import Foundation_iOS

final class FormatterCache {
    private var displayFormatters: [DisplayFormatterKey: LocalizableResource<LocalizableDecimalFormatting>] = [:]
    private var tokenFormatters: [TokenFormatterKey: LocalizableResource<TokenFormatter>] = [:]
    private var assetPriceFormatters: [AssetPriceFormatterKey: LocalizableResource<TokenFormatter>] = [:]

    private let factory: AssetBalanceFormatterFactoryProtocol

    private let queue = DispatchQueue(
        label: "com.nova.wallet.formatter.cache",
        attributes: .concurrent
    )

    init(factory: AssetBalanceFormatterFactoryProtocol) {
        self.factory = factory
    }

    func displayFormatter(for info: AssetBalanceDisplayInfo) -> LocalizableResource<LocalizableDecimalFormatting> {
        let key = DisplayFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator
        )

        return queue.sync {
            if let cached = displayFormatters[key] {
                return cached
            }

            let formatter = factory.createDisplayFormatter(for: info)

            queue.async(flags: .barrier) {
                self.displayFormatters[key] = formatter
            }

            return formatter
        }
    }

    func tokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode = .down,
        useSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        let key = TokenFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        )

        return queue.sync {
            if let cached = tokenFormatters[key] {
                return cached
            }

            let formatter = factory.createTokenFormatter(
                for: info,
                roundingMode: roundingMode,
                useSuffixForBigNumbers: useSuffixForBigNumbers
            )

            queue.async(flags: .barrier) {
                self.tokenFormatters[key] = formatter
            }

            return formatter
        }
    }

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        let key = AssetPriceFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        )

        return queue.sync {
            if let cached = assetPriceFormatters[key] {
                return cached
            }

            let formatter = factory.createAssetPriceFormatter(
                for: info,
                useSuffixForBigNumbers: useSuffixForBigNumbers
            )

            queue.async(flags: .barrier) {
                self.assetPriceFormatters[key] = formatter
            }

            return formatter
        }
    }

    func clearCache() {
        queue.async(flags: .barrier) {
            self.displayFormatters.removeAll()
            self.tokenFormatters.removeAll()
            self.assetPriceFormatters.removeAll()
        }
    }
}

// MARK: - Private types

private extension FormatterCache {
    struct DisplayFormatterKey: Hashable {
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
    }

    struct TokenFormatterKey: Hashable {
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let roundingMode: NumberFormatter.RoundingMode
        let useSuffixForBigNumbers: Bool
    }

    struct AssetPriceFormatterKey: Hashable {
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let useSuffixForBigNumbers: Bool
    }
}
