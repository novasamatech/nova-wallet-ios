import Foundation
import Foundation_iOS
import BigInt

protocol AssetFormattingCacheProtocol {
    func formatDecimal(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String

    func formatBigUInt(
        _ value: BigUInt,
        info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String

    func formatToken(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> String

    func formatPrice(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> String

    func displayFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> LocalizableDecimalFormatting

    func inputFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> NumberFormatter

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

    func clearCache()
}

extension AssetFormattingCacheProtocol {
    func formatToken(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode = .down,
        useSuffixForBigNumbers: Bool = true,
        locale: Locale
    ) -> String {
        formatToken(
            value,
            info: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )
    }

    func formatPrice(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool = true,
        locale: Locale
    ) -> String {
        formatPrice(
            value,
            info: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )
    }

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

final class AssetFormattingCache {
    private let formatterCache: FormatterCacheProtocol

    init(factory: AssetBalanceFormatterFactoryProtocol) {
        formatterCache = FormatterCache(factory: factory)
    }
}

// MARK: - AssetFormattingCacheProtocol

extension AssetFormattingCache: AssetFormattingCacheProtocol {
    func formatDecimal(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        formatterCache
            .displayFormatter(for: info, locale: locale)
            .stringFromDecimal(value) ?? ""
    }

    func formatBigUInt(
        _ value: BigUInt,
        info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        let decimal = Decimal.fromSubstrateAmount(
            value,
            precision: info.assetPrecision
        ) ?? 0.0

        let formatter = formatterCache.displayFormatter(
            for: info,
            locale: locale
        )

        return formatter.stringFromDecimal(decimal) ?? ""
    }

    func formatToken(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> String {
        formatterCache
            .tokenFormatter(
                for: info,
                roundingMode: roundingMode,
                useSuffixForBigNumbers: useSuffixForBigNumbers,
                locale: locale
            )
            .stringFromDecimal(value) ?? ""
    }

    func formatPrice(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> String {
        formatterCache
            .assetPriceFormatter(
                for: info,
                useSuffixForBigNumbers: useSuffixForBigNumbers,
                locale: locale
            )
            .stringFromDecimal(value) ?? ""
    }

    func displayFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> LocalizableDecimalFormatting {
        formatterCache.displayFormatter(for: info, locale: locale)
    }

    func inputFormatter(
        for info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> NumberFormatter {
        formatterCache.inputFormatter(for: info, locale: locale)
    }

    func tokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> TokenFormatter {
        formatterCache.tokenFormatter(
            for: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )
    }

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> TokenFormatter {
        formatterCache.assetPriceFormatter(
            for: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )
    }

    func clearCache() {
        formatterCache.clearCache()
    }
}
