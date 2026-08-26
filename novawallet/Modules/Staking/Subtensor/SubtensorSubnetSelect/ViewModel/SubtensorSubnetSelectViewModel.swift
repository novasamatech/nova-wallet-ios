import BigInt
import Foundation
import SubstrateSdk

struct SubtensorSubnetSelectViewModel {
    let target: SubtensorStakeTarget
    let icon: DrawableIcon?
    let title: String
    let subtitle: String
    let price: String?
    let apr: String?
    let aprDetail: String?
}

protocol SubtensorSubnetViewModelFactoryProtocol {
    func createViewModels(
        from info: SubtensorSubnetsInfo,
        defaultTake: UInt16?,
        query: String,
        locale: Locale
    ) -> [SubtensorSubnetSelectViewModel]
}

final class SubtensorSubnetViewModelFactory {
    /// InitialDefaultDelegateTake at the verified pin; used only until the live
    /// metadata constant arrives
    static let fallbackDelegateTake: UInt16 = 11796

    let chainAsset: ChainAsset

    private let iconGenerator = PolkadotIconGenerator()
    private lazy var tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(
        for: chainAsset.assetDisplayInfo
    )

    private lazy var percentFormatter = NumberFormatter.percentSingle.localizableResource()

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }
}

private extension SubtensorSubnetViewModelFactory {
    func matches(query: String, name: String, symbol: String, netuid: UInt16) -> Bool {
        guard !query.isEmpty else {
            return true
        }

        return name.localizedCaseInsensitiveContains(query) ||
            symbol.localizedCaseInsensitiveContains(query) ||
            String(netuid) == query
    }

    func formatPrice(_ price: Balance, locale: Locale) -> String? {
        let decimal = price.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return tokenFormatter.value(for: locale).stringFromDecimal(decimal)
    }

    func formatApr(ppm: BigUInt, locale: Locale) -> String? {
        let decimal = Decimal(string: String(ppm)).map { $0 / 1_000_000 }

        guard
            let decimal,
            let percent = percentFormatter.value(for: locale).stringFromDecimal(decimal) else {
            return nil
        }

        return percent.approximately()
    }

    func createRootViewModel(locale: Locale) -> SubtensorSubnetSelectViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorSubnetSelectViewModel(
            target: .root,
            icon: nil,
            title: strings.stakingSubtensorRootNetwork(),
            subtitle: chainAsset.asset.symbol,
            price: formatPrice(SubtensorStakingPallet.alphaPriceScale, locale: locale),
            apr: nil,
            aprDetail: nil
        )
    }

    func createSubnetViewModel(
        info: SubtensorStakingPallet.DynamicInfo,
        price: Balance,
        ownerCut: UInt16,
        take: UInt16,
        locale: Locale
    ) -> SubtensorSubnetSelectViewModel {
        let name = info.displayName
        let symbol = info.displaySymbol

        let aprPpm = SubtensorAlphaAprCalculator.aprPpm(
            for: info,
            ownerCut: ownerCut,
            take: take
        )

        let apr = aprPpm.flatMap { formatApr(ppm: $0, locale: locale) }

        let aprDetail: String? = apr != nil
            ? R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorAprInSymbol(
                symbol.isEmpty ? "SN\(info.netuid)" : symbol
            )
            : nil

        return SubtensorSubnetSelectViewModel(
            target: .subnet(info: info, price: price),
            icon: try? iconGenerator.generateFromAccountId(info.ownerHotkey),
            title: name.isEmpty ? "SN\(info.netuid)" : name,
            subtitle: [symbol, "SN\(info.netuid)"]
                .filter { !$0.isEmpty }
                .joined(separator: " · "),
            price: formatPrice(price, locale: locale),
            apr: apr,
            aprDetail: aprDetail
        )
    }
}

extension SubtensorSubnetViewModelFactory: SubtensorSubnetViewModelFactoryProtocol {
    func createViewModels(
        from info: SubtensorSubnetsInfo,
        defaultTake: UInt16?,
        query: String,
        locale: Locale
    ) -> [SubtensorSubnetSelectViewModel] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let take = defaultTake ?? Self.fallbackDelegateTake

        let rootTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorRootNetwork()

        let rootMatches = matches(
            query: trimmedQuery,
            name: rootTitle,
            symbol: chainAsset.asset.symbol,
            netuid: SubtensorStakingPallet.rootNetuid
        )

        let subnetViewModels: [SubtensorSubnetSelectViewModel] = info.subnets
            .filter { subnet in
                subnet.netuid != SubtensorStakingPallet.rootNetuid &&
                    info.subtokenEnabled.contains(subnet.netuid) &&
                    matches(
                        query: trimmedQuery,
                        name: subnet.displayName,
                        symbol: subnet.displaySymbol,
                        netuid: subnet.netuid
                    )
            }
            .sorted { $0.netuid < $1.netuid }
            .compactMap { subnet in
                guard let price = info.prices[subnet.netuid] else {
                    return nil
                }

                return createSubnetViewModel(
                    info: subnet,
                    price: price,
                    ownerCut: info.ownerCut,
                    take: take,
                    locale: locale
                )
            }

        // root stays pinned first so the flow can always return to the default lane
        let rootViewModels = rootMatches ? [createRootViewModel(locale: locale)] : []

        return rootViewModels + subnetViewModels
    }
}
