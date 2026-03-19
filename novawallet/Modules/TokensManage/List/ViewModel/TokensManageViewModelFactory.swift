import Foundation
import Foundation_iOS

protocol TokensManageViewModelFactoryProtocol {
    func createSingleViewModel(from token: MultichainToken, locale: Locale) -> TokenManageViewModel

    func createTokenSections(
        from tokens: [MultichainToken],
        chains: [ChainModel],
        expandedIndex: Int?,
        locale: Locale
    ) -> [ManageTokenSection]

    func createNetworkSections(
        from chains: [ChainModel],
        expandedIndex: Int?,
        locale: Locale
    ) -> [ManageTokenSection]
}

final class TokensManageViewModelFactory {
    let quantityFormater: LocalizableResource<NumberFormatter>
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    private static let tokenPriorityOrder = ["DOT", "KSM", "USDC", "USDT", "ETH", "HOLLAR", "TBTC", "HDX", "SOL"]

    private static let networkPriorityChainIds: [ChainModel.Id: Int] = [
        KnowChainId.polkadotAssetHub: 0,
        KnowChainId.kusamaAssetHub: 1,
        KnowChainId.ethereum: 2,
        KnowChainId.hydra: 3
    ]

    private static let systemChainKeywords = ["People", "Coretime", "Bridge Hub", "Collectives"]

    init(
        quantityFormater: LocalizableResource<NumberFormatter>,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    ) {
        self.quantityFormater = quantityFormater
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }

    private static func normalizeForPriority(_ symbol: String) -> String {
        let uppercased = symbol.uppercased()
        if let range = uppercased.range(of: #"-(SNOWBRIDGE|WORMHOLE).*"#, options: [.regularExpression, .caseInsensitive]) {
            return String(uppercased[uppercased.startIndex ..< range.lowerBound])
        }
        return uppercased
    }

    private static func tokenPriorityIndex(for symbol: String) -> Int {
        let normalized = normalizeForPriority(symbol)
        if let index = tokenPriorityOrder.firstIndex(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return index
        }
        return Int.max
    }

    private static func networkPriorityIndex(for chain: ChainModel) -> Int {
        if let priority = networkPriorityChainIds[chain.chainId] {
            return priority
        }

        let isSystemChain = systemChainKeywords.contains { keyword in
            chain.name.localizedCaseInsensitiveContains(keyword)
        }

        return isSystemChain ? 4 : 5
    }

    private func createSubtitle(
        from token: MultichainToken,
        locale: Locale
    ) -> String {
        let enabledInstances = token.enabledInstances()

        if enabledInstances.isEmpty || token.instances.count == enabledInstances.count {
            return R.string(preferredLanguages: locale.rLanguages).localizable.tokensManageAllSelected()
        } else if let instance = enabledInstances.first {
            if enabledInstances.count > 1 {
                let chainsCount = quantityFormater.value(for: locale).string(
                    from: NSNumber(value: enabledInstances.count - 1)
                )
                return R.string(preferredLanguages: locale.rLanguages
                ).localizable.tokensManagePartialSelected(instance.chainName, chainsCount ?? "")
            } else {
                return instance.chainName
            }
        } else {
            return ""
        }
    }
}

extension TokensManageViewModelFactory: TokensManageViewModelFactoryProtocol {
    func createSingleViewModel(from token: MultichainToken, locale: Locale) -> TokenManageViewModel {
        let imageViewModel = assetIconViewModelFactory.createAssetIconViewModel(for: token.icon)
        let subtitle = createSubtitle(from: token, locale: locale)

        return .init(symbol: token.symbol, imageViewModel: imageViewModel, subtitle: subtitle, isOn: token.enabled)
    }

    func createTokenSections(
        from tokens: [MultichainToken],
        chains: [ChainModel],
        expandedIndex: Int?,
        locale _: Locale
    ) -> [ManageTokenSection] {
        let chainDict = chains.reduce(into: [ChainModel.Id: ChainModel]()) { $0[$1.chainId] = $1 }

        // Merge tokens by normalized base symbol (strips -Snowbridge, -Wormhole suffixes)
        var mergedOrder: [String] = []
        var mergedGroups: [String: [MultichainToken]] = [:]

        for token in tokens {
            let baseSymbol = Self.normalizeForPriority(token.symbol)
            if mergedGroups[baseSymbol] != nil {
                mergedGroups[baseSymbol]!.append(token)
            } else {
                mergedOrder.append(baseSymbol)
                mergedGroups[baseSymbol] = [token]
            }
        }

        let sortedKeys = mergedOrder.sorted { key1, key2 in
            let priority1 = Self.tokenPriorityIndex(for: key1)
            let priority2 = Self.tokenPriorityIndex(for: key2)
            if priority1 != priority2 {
                return priority1 < priority2
            }
            return key1.localizedCaseInsensitiveCompare(key2) == .orderedAscending
        }

        return sortedKeys.enumerated().map { index, baseSymbol in
            let group = mergedGroups[baseSymbol]!
            let hasMultipleSymbols = Set(group.map(\.symbol)).count > 1

            let icon = assetIconViewModelFactory.createAssetIconViewModel(for: group.first?.icon)

            let items: [ManageTokenItem] = group.flatMap { token in
                token.instances.compactMap { instance -> ManageTokenItem? in
                    guard let chain = chainDict[instance.chainAssetId.chainId] else {
                        return nil
                    }

                    let chainIcon = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)

                    let name: String
                    if hasMultipleSymbols, token.symbol.caseInsensitiveCompare(baseSymbol) != .orderedSame {
                        name = "\(token.symbol) on \(chain.name)"
                    } else {
                        name = chain.name
                    }

                    return ManageTokenItem(
                        chainAssetId: instance.chainAssetId,
                        name: name,
                        icon: chainIcon,
                        isEnabled: instance.enabled
                    )
                }
            }

            let enabledCount = items.filter(\.isEnabled).count

            return ManageTokenSection(
                title: baseSymbol,
                icon: icon,
                items: items,
                isExpanded: expandedIndex == index,
                enabledCount: enabledCount
            )
        }
    }

    func createNetworkSections(
        from chains: [ChainModel],
        expandedIndex: Int?,
        locale _: Locale
    ) -> [ManageTokenSection] {
        let sortedChains = chains.sorted { chain1, chain2 in
            let priority1 = Self.networkPriorityIndex(for: chain1)
            let priority2 = Self.networkPriorityIndex(for: chain2)
            if priority1 != priority2 {
                return priority1 < priority2
            }
            return chain1.name.localizedCaseInsensitiveCompare(chain2.name) == .orderedAscending
        }

        let nonEmptyChains = sortedChains.filter { !$0.assets.isEmpty }

        return nonEmptyChains.enumerated().map { index, chain in
            let assets = chain.assets.sorted { $0.assetId < $1.assetId }

            let chainIcon = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)

            let items: [ManageTokenItem] = assets.map { asset in
                let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(for: asset.icon)

                return ManageTokenItem(
                    chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
                    name: asset.symbol,
                    icon: assetIcon,
                    isEnabled: asset.enabled
                )
            }

            let enabledCount = items.filter(\.isEnabled).count

            return ManageTokenSection(
                title: chain.name,
                icon: chainIcon,
                items: items,
                isExpanded: expandedIndex == index,
                enabledCount: enabledCount
            )
        }
    }
}
