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

    private var locale: Locale = .current

    private let mutex = NSLock()

    private let factory: AssetBalanceFormatterFactoryProtocol

    init(factory: AssetBalanceFormatterFactoryProtocol) {
        self.factory = factory
    }
}

// MARK: - Private

private extension FormatterCache {
    func clearFormatters() {
        displayFormatters.removeAllValues()
        tokenFormatters.removeAllValues()
        assetPriceFormatters.removeAllValues()
        inputFormatters.removeAllValues()
    }

    func flush(to locale: Locale) {
        clearFormatters()

        mutex.lock()
        self.locale = locale
        mutex.unlock()
    }

    func flushIfNeeded(to locale: Locale) {
        guard self.locale != locale else { return }

        flush(to: locale)
    }
}

// MARK: - FormatterCacheProtocol

extension FormatterCache: FormatterCacheProtocol {
    func displayFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> LocalizableDecimalFormatting {
        flushIfNeeded(to: locale)

        let key = DisplayFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator
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
        flushIfNeeded(to: locale)

        let key = TokenFormatterKey(
            info: info,
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
        flushIfNeeded(to: locale)

        let key = AssetPriceFormatterKey(
            info: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers
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
        flushIfNeeded(to: locale)

        let key = InputFormatterKey(
            assetPrecision: info.assetPrecision,
            symbol: info.symbol,
            symbolPosition: info.symbolPosition,
            symbolValueSeparator: info.symbolValueSeparator
        )

        if let cached = inputFormatters.fetchValue(for: key) {
            return cached
        }

        let formatter = factory.createInputFormatter(for: info).value(for: locale)

        inputFormatters.store(value: formatter, for: key)

        return formatter
    }

    func clearCache() {
        clearFormatters()
    }
}

// MARK: - Private types

private extension FormatterCache {
    protocol CacheKey: Hashable {
        var prefix: String { get }
    }

    struct DisplayFormatterKey: CacheKey {
        var prefix: String { "display" }

        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
    }

    struct InputFormatterKey: CacheKey {
        var prefix: String { "input" }

        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
    }

    struct TokenFormatterKey: CacheKey {
        var prefix: String { "token" }

        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let roundingMode: NumberFormatter.RoundingMode
        let useSuffixForBigNumbers: Bool

        init(
            assetPrecision: Int16,
            symbol: String,
            symbolPosition: TokenSymbolPosition,
            symbolValueSeparator: String,
            roundingMode: NumberFormatter.RoundingMode,
            useSuffixForBigNumbers: Bool
        ) {
            self.assetPrecision = assetPrecision
            self.symbol = symbol
            self.symbolPosition = symbolPosition
            self.symbolValueSeparator = symbolValueSeparator
            self.roundingMode = roundingMode
            self.useSuffixForBigNumbers = useSuffixForBigNumbers
        }

        init(
            info: AssetBalanceDisplayInfo,
            roundingMode: NumberFormatter.RoundingMode,
            useSuffixForBigNumbers: Bool
        ) {
            assetPrecision = info.assetPrecision
            symbol = info.symbol
            symbolPosition = info.symbolPosition
            symbolValueSeparator = info.symbolValueSeparator
            self.roundingMode = roundingMode
            self.useSuffixForBigNumbers = useSuffixForBigNumbers
        }
    }

    struct AssetPriceFormatterKey: CacheKey {
        var prefix: String { "asset_price" }

        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let useSuffixForBigNumbers: Bool

        init(
            assetPrecision: Int16,
            symbol: String,
            symbolPosition: TokenSymbolPosition,
            symbolValueSeparator: String,
            useSuffixForBigNumbers: Bool
        ) {
            self.assetPrecision = assetPrecision
            self.symbol = symbol
            self.symbolPosition = symbolPosition
            self.symbolValueSeparator = symbolValueSeparator
            self.useSuffixForBigNumbers = useSuffixForBigNumbers
        }

        init(
            info: AssetBalanceDisplayInfo,
            useSuffixForBigNumbers: Bool,
        ) {
            assetPrecision = info.assetPrecision
            symbol = info.symbol
            symbolPosition = info.symbolPosition
            symbolValueSeparator = info.symbolValueSeparator
            self.useSuffixForBigNumbers = useSuffixForBigNumbers
        }
    }
}

extension FormatterCache.CacheKey {
    func hash(into hasher: inout Hasher) {
        hasher.combine(prefix)
        hasher.combine(self)
    }
}
