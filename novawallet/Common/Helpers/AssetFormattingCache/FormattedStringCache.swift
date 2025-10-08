import Foundation
import Foundation_iOS
import BigInt

protocol FormattedStringCacheProtocol {
    func getOrCreateDecimalString(
        for value: Decimal,
        info: AssetBalanceDisplayInfo,
        locale: Locale,
        formatter: (Decimal) -> String?
    ) -> String

    func getOrCreateBigUIntString(
        for value: BigUInt,
        info: AssetBalanceDisplayInfo,
        locale: Locale,
        formatter: (BigUInt) -> String?
    ) -> String

    func getOrCreatePriceString(
        for value: Decimal,
        info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale,
        formatter: (Decimal) -> String?
    ) -> String

    func clearCache()
}

final class FormattedStringCache {
    private var decimalCache: [CacheKey: String] = [:]
    private var bigUIntCache: [CacheKey: String] = [:]
    private var priceCache: [CacheKey: String] = [:]

    private let syncQueue = DispatchQueue(
        label: "com.nova.wallet.formatted.string.cache",
        attributes: .concurrent
    )
}

// MARK: - FormattedStringCacheProtocol

extension FormattedStringCache: FormattedStringCacheProtocol {
    func getOrCreateDecimalString(
        for value: Decimal,
        info: AssetBalanceDisplayInfo,
        locale: Locale,
        formatter: (Decimal) -> String?
    ) -> String {
        let key = CacheKey(value: value, info: info, locale: locale)

        return syncQueue.sync {
            if let cached = decimalCache[key] {
                return cached
            }

            let formatted = formatter(value) ?? ""

            syncQueue.async(flags: .barrier) {
                self.decimalCache[key] = formatted
            }

            return formatted
        }
    }

    func getOrCreateBigUIntString(
        for value: BigUInt,
        info: AssetBalanceDisplayInfo,
        locale: Locale,
        formatter: (BigUInt) -> String?
    ) -> String {
        let key = CacheKey(value: value, info: info, locale: locale)

        return syncQueue.sync {
            if let cached = bigUIntCache[key] {
                return cached
            }

            let formatted = formatter(value) ?? ""

            syncQueue.async(flags: .barrier) {
                self.bigUIntCache[key] = formatted
            }

            return formatted
        }
    }

    func getOrCreatePriceString(
        for value: Decimal,
        info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool,
        locale: Locale,
        formatter: (Decimal) -> String?
    ) -> String {
        let key = CacheKey(
            value: value,
            info: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers,
            locale: locale
        )

        return syncQueue.sync {
            if let cached = priceCache[key] {
                return cached
            }

            let formatted = formatter(value) ?? ""

            syncQueue.async(flags: .barrier) {
                self.priceCache[key] = formatted
            }

            return formatted
        }
    }

    func clearCache() {
        syncQueue.async(flags: .barrier) {
            self.decimalCache.removeAll()
            self.bigUIntCache.removeAll()
            self.priceCache.removeAll()
        }
    }
}

// MARK: - Private types

private extension FormattedStringCache {
    struct CacheKey: Hashable {
        let value: String
        let assetPrecision: Int16
        let symbol: String
        let symbolPosition: TokenSymbolPosition
        let symbolValueSeparator: String
        let roundingMode: NumberFormatter.RoundingMode
        let useSuffixForBigNumbers: Bool
        let locale: String

        init(
            value: Decimal,
            info: AssetBalanceDisplayInfo,
            roundingMode: NumberFormatter.RoundingMode = .down,
            useSuffixForBigNumbers: Bool = true,
            locale: Locale
        ) {
            self.value = value.description
            assetPrecision = info.assetPrecision
            symbol = info.symbol
            symbolPosition = info.symbolPosition
            symbolValueSeparator = info.symbolValueSeparator
            self.roundingMode = roundingMode
            self.useSuffixForBigNumbers = useSuffixForBigNumbers
            self.locale = locale.identifier
        }

        init(
            value: BigUInt,
            info: AssetBalanceDisplayInfo,
            roundingMode: NumberFormatter.RoundingMode = .down,
            useSuffixForBigNumbers: Bool = true,
            locale: Locale
        ) {
            self.value = value.description
            assetPrecision = info.assetPrecision
            symbol = info.symbol
            symbolPosition = info.symbolPosition
            symbolValueSeparator = info.symbolValueSeparator
            self.roundingMode = roundingMode
            self.useSuffixForBigNumbers = useSuffixForBigNumbers
            self.locale = locale.identifier
        }
    }
}
