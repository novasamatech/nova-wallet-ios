import Foundation
import Foundation_iOS

protocol FormatterCacheProtocol {
    func displayFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> LocalizableDecimalFormatting

    func tokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> TokenFormatter

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> TokenFormatter

    func inputFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> NumberFormatter

    func clearCache()
}

extension FormatterCacheProtocol {
    func tokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode = .down,
        useSuffixForBigNumbers: Bool = true,
        locale: Locale
    ) -> TokenFormatter {
        tokenFormatter(
            for: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )
    }

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool = true,
        locale: Locale
    ) -> TokenFormatter {
        assetPriceFormatter(
            for: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )
    }
}

final class FormatterCache {
    private var displayFormatters: InMemoryCache<DisplayFormatterKey, LocalizableDecimalFormatting> = .init()
    private var tokenFormatters: InMemoryCache<TokenFormatterKey, TokenFormatter> = .init()
    private var assetPriceFormatters: InMemoryCache<AssetPriceFormatterKey, TokenFormatter> = .init()
    private var inputFormatters: InMemoryCache<InputFormatterKey, NumberFormatter> = .init()

    private let factory: AssetBalanceFormatterFactoryProtocol

    init(factory: AssetBalanceFormatterFactoryProtocol) {
        self.factory = factory
    }
}

// MARK: - FormatterCacheProtocol

extension FormatterCache: FormatterCacheProtocol {
    func displayFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> LocalizableDecimalFormatting {
        let key = DisplayFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator,
            locale: locale
        )

        if let cached = displayFormatters.fetchValue(for: key) {
            return cached
        }

        let formatter = factory.createDisplayFormatter(for: info).value(for: locale)

        displayFormatters.store(value: formatter, for: key)

        return formatter
    }

    func tokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> TokenFormatter {
        let key = TokenFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )

        if let cached = tokenFormatters.fetchValue(for: key) {
            return cached
        }

        let formatter = factory.createTokenFormatter(
            for: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        ).value(for: locale)

        tokenFormatters.store(value: formatter, for: key)

        return formatter
    }

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> TokenFormatter {
        let key = AssetPriceFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )

        if let cached = assetPriceFormatters.fetchValue(for: key) {
            return cached
        }

        let formatter = factory.createAssetPriceFormatter(
            for: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        ).value(for: locale)

        assetPriceFormatters.store(value: formatter, for: key)

        return formatter
    }

    func inputFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> NumberFormatter {
        let key = InputFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator,
            locale: locale
        )

        if let cached = inputFormatters.fetchValue(for: key) {
            return cached
        }

        let formatter = factory.createInputFormatter(for: info).value(for: locale)

        inputFormatters.store(value: formatter, for: key)

        return formatter
    }

    func clearCache() {
        displayFormatters.removeAllValues()
        tokenFormatters.removeAllValues()
        assetPriceFormatters.removeAllValues()
    }
}

// MARK: - Private types

private extension FormatterCache {
    struct DisplayFormatterKey: Hashable {
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let locale: Locale
    }

    struct InputFormatterKey: Hashable {
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let locale: Locale
    }

    struct TokenFormatterKey: Hashable {
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let roundingMode: NumberFormatter.RoundingMode
        let useSuffixForBigNumbers: Bool
        let locale: Locale
    }

    struct AssetPriceFormatterKey: Hashable {
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let useSuffixForBigNumbers: Bool
        let locale: Locale
    }
}
