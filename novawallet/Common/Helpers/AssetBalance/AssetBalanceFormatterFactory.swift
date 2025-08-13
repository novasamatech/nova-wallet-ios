import Foundation
import Foundation_iOS

protocol AssetBalanceFormatterFactoryProtocol {
    func createInputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter>

    func createDisplayFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<LocalizableDecimalFormatting>

    func createTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter>

    func createAssetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter>

    func createInputTokenFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<TokenFormatter>
}

extension AssetBalanceFormatterFactoryProtocol {
    func createTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode = .down,
        usesSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatter(
            for: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: usesSuffixForBigNumbers
        )
    }

    func createFeeTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode = .up,
        usesSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatter(
            for: info,
            roundingMode: roundingMode,
            useSuffixForBigNumbers: usesSuffixForBigNumbers
        )
    }

    func createAssetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        createAssetPriceFormatter(
            for: info,
            useSuffixForBigNumbers: useSuffixForBigNumbers
        )
    }
}

class AssetBalanceFormatterFactory {
    private func createTokenFormatterCommon(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        preferredPrecisionOffset: UInt8 = 0,
        usesSuffixForBigNumbers: Bool = true
    ) -> LocalizableResource<TokenFormatter> {
        let formatter = createCompoundFormatter(
            for: info.displayPrecision,
            roundingMode: roundingMode,
            prefferedPrecisionOffset: preferredPrecisionOffset,
            usesSuffixForBigNumber: usesSuffixForBigNumbers
        )

        let tokenFormatter = TokenFormatter(
            decimalFormatter: formatter,
            tokenSymbol: info.symbol,
            separator: info.symbolValueSeparator,
            position: info.symbolPosition
        )

        return LocalizableResource { locale in
            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }

    // swiftlint:disable function_body_length
    private func createCompoundFormatter(
        for preferredPrecision: UInt16,
        roundingMode: NumberFormatter.RoundingMode = .down,
        prefferedPrecisionOffset: UInt8 = 0,
        usesSuffixForBigNumber: Bool = true
    ) -> LocalizableDecimalFormatting {
        var abbreviations: [BigNumberAbbreviation] = [
            BigNumberAbbreviation(
                threshold: 0,
                divisor: 1.0,
                suffix: "",
                formatter: DynamicPrecisionFormatter(
                    preferredPrecision: UInt8(preferredPrecision),
                    preferredPrecisionOffset: prefferedPrecisionOffset,
                    roundingMode: roundingMode
                )
            ),
            BigNumberAbbreviation(
                threshold: 1,
                divisor: 1.0,
                suffix: "",
                formatter: NumberFormatter.decimalFormatter(
                    precision: Int(preferredPrecision),
                    rounding: roundingMode,
                    usesIntGrouping: true
                )
            ),
            BigNumberAbbreviation(
                threshold: 10,
                divisor: 1.0,
                suffix: "",
                formatter: nil
            )
        ]

        if usesSuffixForBigNumber {
            abbreviations.append(contentsOf: [
                BigNumberAbbreviation(
                    threshold: 1_000_000,
                    divisor: 1_000_000.0,
                    suffix: "M",
                    formatter: nil
                ),
                BigNumberAbbreviation(
                    threshold: 1_000_000_000,
                    divisor: 1_000_000_000.0,
                    suffix: "B",
                    formatter: nil
                ),
                BigNumberAbbreviation(
                    threshold: 1_000_000_000_000,
                    divisor: 1_000_000_000_000.0,
                    suffix: "T",
                    formatter: nil
                )
            ])
        }

        return BigNumberFormatter(
            abbreviations: abbreviations,
            precision: 2,
            rounding: roundingMode,
            usesIntGrouping: true
        )
    }
}

extension AssetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol {
    func createInputFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.maximumSignificantDigits = Int(info.assetPrecision)
        formatter.maximumFractionDigits = Int(info.assetPrecision)
        return formatter.localizableResource()
    }

    func createDisplayFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<LocalizableDecimalFormatting> {
        let formatter = createCompoundFormatter(for: info.displayPrecision)
        return LocalizableResource { locale in
            formatter.locale = locale
            return formatter
        }
    }

    func createTokenFormatter(
        for info: AssetBalanceDisplayInfo,
        roundingMode: NumberFormatter.RoundingMode,
        useSuffixForBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatterCommon(
            for: info,
            roundingMode: roundingMode,
            usesSuffixForBigNumbers: useSuffixForBigNumbers
        )
    }

    func createAssetPriceFormatter(
        for info: AssetBalanceDisplayInfo,
        useSuffixForBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter> {
        createTokenFormatterCommon(
            for: info,
            roundingMode: .down,
            preferredPrecisionOffset: 2,
            usesSuffixForBigNumbers: useSuffixForBigNumbers
        )
    }

    func createInputTokenFormatter(
        for info: AssetBalanceDisplayInfo
    ) -> LocalizableResource<TokenFormatter> {
        let formatter = NumberFormatter.amount
        formatter.maximumSignificantDigits = Int(info.assetPrecision)
        formatter.maximumFractionDigits = Int(info.assetPrecision)

        let tokenFormatter = TokenFormatter(
            decimalFormatter: formatter,
            tokenSymbol: info.symbol,
            separator: info.symbolValueSeparator,
            position: info.symbolPosition
        )

        return LocalizableResource { locale in
            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }
}
