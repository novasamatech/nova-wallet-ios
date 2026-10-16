import Foundation

enum SubtensorSubnetNaming {
    static func title(for subnet: SubtensorCatalogueSubnet, locale: Locale) -> String {
        title(name: subnet.name, netuid: subnet.netuid, locale: locale)
    }

    static func titleWithSymbol(for subnet: SubtensorCatalogueSubnet, locale: Locale) -> String {
        titleWithSymbol(name: subnet.name, symbol: subnet.symbol, netuid: subnet.netuid, locale: locale)
    }

    static func symbol(for subnet: SubtensorCatalogueSubnet) -> String {
        symbol(subnet.symbol, netuid: subnet.netuid)
    }

    static func title(for netuid: UInt16, in catalogue: SubtensorSubnetCatalogue?, locale: Locale) -> String {
        title(name: catalogue?.subnet(for: netuid)?.name, netuid: netuid, locale: locale)
    }

    static func titleWithSymbol(
        for netuid: UInt16,
        in catalogue: SubtensorSubnetCatalogue?,
        locale: Locale
    ) -> String {
        let subnet = catalogue?.subnet(for: netuid)

        return titleWithSymbol(name: subnet?.name, symbol: subnet?.symbol, netuid: netuid, locale: locale)
    }

    static func symbol(for netuid: UInt16, in catalogue: SubtensorSubnetCatalogue?) -> String {
        symbol(catalogue?.subnet(for: netuid)?.symbol, netuid: netuid)
    }

    static func isolatedLeftToRight(_ text: String) -> String {
        "\u{2066}\(text)\u{2069}"
    }

    static func isolatedRate(_ oneIn: String, _ rateOut: String) -> String {
        isolatedLeftToRight(isolatedLeftToRight(oneIn).estimatedEqual(to: isolatedLeftToRight(rateOut)))
    }
}

private extension SubtensorSubnetNaming {
    static func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        return value
    }

    static func title(name: String?, netuid: UInt16, locale: Locale) -> String {
        trimmed(name) ??
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiSubnetFormat(Int(netuid))
    }

    static func titleWithSymbol(name: String?, symbol: String?, netuid: UInt16, locale: Locale) -> String {
        let title = title(name: name, netuid: netuid, locale: locale)

        guard let symbol = trimmed(symbol) else {
            return title
        }

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiJoinSpaceFormat(
            title,
            symbol
        )
    }

    static func symbol(_ symbol: String?, netuid: UInt16) -> String {
        trimmed(symbol) ?? "SN\(netuid)"
    }
}

extension AssetBalanceDisplayInfo {
    func subtensorAlpha(symbol: String) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: displayPrecision,
            assetPrecision: assetPrecision,
            symbol: symbol,
            symbolValueSeparator: symbolValueSeparator,
            symbolPosition: symbolPosition,
            icon: nil
        )
    }

    func subtensorAlpha(netuid: UInt16, catalogue: SubtensorSubnetCatalogue?) -> AssetBalanceDisplayInfo {
        guard netuid != SubtensorStakingPallet.rootNetuid else {
            return self
        }

        return subtensorAlpha(symbol: SubtensorSubnetNaming.symbol(for: netuid, in: catalogue))
    }
}

extension PrimitiveBalanceViewModelFactoryProtocol {
    func subtensorFee(
        _ fee: ExtrinsicFeeProtocol?,
        info: AssetBalanceDisplayInfo,
        price: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        fee.map { fee in
            balanceFromPrice(
                fee.amount.decimal(assetInfo: info),
                priceData: price,
                roundingMode: .up
            ).value(for: locale)
        }
    }
}

extension String {
    static func subtensorUnknown(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }
}
