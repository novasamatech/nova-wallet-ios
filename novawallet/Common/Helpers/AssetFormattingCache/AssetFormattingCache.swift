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
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<LocalizableDecimalFormatting>

    func inputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter>

    func tokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter>

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter>

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
        useSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        tokenFormatter(
            for: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        )
    }

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        assetPriceFormatter(
            for: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        )
    }
}

final class AssetFormattingCache {
    private let formatterCache: FormatterCacheProtocol
    private let formattedStringCache: FormattedStringCacheProtocol

    init(factory: AssetBalanceFormatterFactoryProtocol) {
        formatterCache = FormatterCache(factory: factory)
        formattedStringCache = FormattedStringCache()
    }
}

// MARK: - AssetFormattingCacheProtocol

extension AssetFormattingCache: AssetFormattingCacheProtocol {
    func formatDecimal(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        formattedStringCache.getOrCreateDecimalString(
            for: value,
            info: info,
            locale: locale
        ) { [weak self] decimal in
            guard let self else { return nil }

            let formatter = formatterCache.displayFormatter(for: info)

            return formatter.value(for: locale).stringFromDecimal(decimal)
        }
    }

    func formatBigUInt(
        _ value: BigUInt,
        info: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        formattedStringCache.getOrCreateBigUIntString(
            for: value,
            info: info,
            locale: locale
        ) { [weak self] bigUInt in
            guard let self else { return nil }

            let decimal = Decimal.fromSubstrateAmount(
                bigUInt,
                precision: info.assetPrecision
            ) ?? 0.0

            let formatter = formatterCache.displayFormatter(for: info)

            return formatter.value(for: locale).stringFromDecimal(decimal)
        }
    }

    func formatToken(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> String {
        formattedStringCache.getOrCreateDecimalString(
            for: value,
            info: info,
            locale: locale
        ) { [weak self] decimal in
            guard let self else { return nil }

            let formatter = formatterCache.tokenFormatter(
                for: info,
                roundingMode: roundingMode,
                useSuffixForBigNumbers: useSuffixForBigNumbers
            )

            return formatter.value(for: locale).stringFromDecimal(decimal)
        }
    }

    func formatPrice(
        _ value: Decimal,
        info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale
    ) -> String {
        formattedStringCache.getOrCreatePriceString(
            for: value,
            info: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        ) { [weak self] decimal in
            guard let self else { return nil }

            let formatter = formatterCache.assetPriceFormatter(
                for: info,
                useSuffixForBigNumbers: useSuffixForBigNumbers
            )

            return formatter.value(for: locale).stringFromDecimal(decimal)
        }
    }

    func displayFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<LocalizableDecimalFormatting> {
        formatterCache.displayFormatter(for: info)
    }

    func inputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter> {
        formatterCache.inputFormatter(for: info)
    }

    func tokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter> {
        formatterCache.tokenFormatter(
            for: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        )
    }

    func assetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        formatterCache.assetPriceFormatter(
            for: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        )
    }

    func clearCache() {
        formatterCache.clearCache()
        formattedStringCache.clearCache()
    }
}
