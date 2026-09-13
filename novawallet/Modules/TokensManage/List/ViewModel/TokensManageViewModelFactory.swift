import Foundation
import Foundation_iOS

protocol TokensManageViewModelFactoryProtocol {
    func createSections(
        from sections: [TokensManageGroupSection],
        expandedIds: Set<String>,
        locale: Locale
    ) -> [TokensManageSection]
}

final class TokensManageViewModelFactory {
    let quantityFormater: LocalizableResource<NumberFormatter>
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(
        quantityFormater: LocalizableResource<NumberFormatter>,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol
    ) {
        self.quantityFormater = quantityFormater
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
    }
}

// MARK: Private

private extension TokensManageViewModelFactory {
    func createItems(
        for group: TokensManageGroup,
        expandedIds: Set<String>,
        locale: Locale
    ) -> [TokensManageListItem] {
        let root = createRootViewModel(for: group, expandedIds: expandedIds, locale: locale)

        guard root.isExpanded else {
            return [.root(root)]
        }

        let children = group.members.map { createChildViewModel(for: $0, in: group) }

        return [.root(root)] + children.map { .child($0) }
    }

    func createRootViewModel(
        for group: TokensManageGroup,
        expandedIds: Set<String>,
        locale: Locale
    ) -> TokensManageRootViewModel {
        // a paused chain syncs nothing, so its row reads as off whatever the stored decisions say
        let visibleCount = group.isPaused ? 0 : group.members.filter(\.isVisible).count

        return TokensManageRootViewModel(
            groupId: group.id,
            title: group.title,
            subtitle: createSubtitle(for: group, visibleCount: visibleCount, locale: locale),
            imageViewModel: createImageViewModel(for: group.icon),
            iconShape: group.kind == .token ? .circle : .roundedSquare,
            isOn: visibleCount > 0,
            isExpandable: group.isExpandable,
            isExpanded: group.isExpandable && expandedIds.contains(group.id),
            isPaused: group.isPaused
        )
    }

    func createChildViewModel(
        for member: TokensManageMember,
        in group: TokensManageGroup
    ) -> TokensManageChildViewModel {
        TokensManageChildViewModel(
            groupId: group.id,
            chainAssetId: member.chainAssetId,
            title: member.title,
            subtitle: member.subtitle,
            imageViewModel: createImageViewModel(for: member.icon),
            kind: group.kind == .token ? .network : .token,
            isOn: member.isVisible
        )
    }

    func createSubtitle(
        for group: TokensManageGroup,
        visibleCount: Int,
        locale: Locale
    ) -> String {
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable
        let total = group.members.count
        let isMixed = visibleCount > 0 && visibleCount < total

        switch group.kind {
        case .token:
            guard !isMixed else {
                return localizedStrings.tokensManagePartialNetworks(visibleCount, total: total)
            }

            return createNetworksSubtitle(for: group.members, locale: locale)
        case .network:
            guard !isMixed else {
                return localizedStrings.tokensManagePartialTokens(visibleCount, total: total)
            }

            return localizedStrings.tokensManageTokensCount(format: total)
        }
    }

    func createNetworksSubtitle(for members: [TokensManageMember], locale: Locale) -> String {
        guard let firstMember = members.first else {
            return ""
        }

        guard members.count > 1 else {
            return firstMember.chainName
        }

        let moreCount = quantityFormater.value(for: locale).string(
            from: NSNumber(value: members.count - 1)
        )

        return R.string(preferredLanguages: locale.rLanguages).localizable.commonMoreFormat(
            firstMember.chainName,
            moreCount ?? ""
        )
    }

    func createImageViewModel(for icon: TokensManageIcon) -> ImageViewModelProtocol? {
        switch icon {
        case let .asset(path):
            return assetIconViewModelFactory.createAssetIconViewModel(for: path)
        case let .chain(chain):
            return networkViewModelFactory.createViewModel(from: chain).icon
        }
    }

    func createTitle(for section: TokensManageGroupSection, locale: Locale) -> String {
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch section.kind {
        case .default:
            return localizedStrings.tokensManageSectionDefault()
        case .others:
            return localizedStrings.tokensManageSectionOthers()
        case .paused:
            return localizedStrings.tokensManageSectionPaused()
        case .results:
            return localizedStrings.tokensManageSearchResults(format: section.groups.count)
        }
    }
}

// MARK: TokensManageViewModelFactoryProtocol

extension TokensManageViewModelFactory: TokensManageViewModelFactoryProtocol {
    func createSections(
        from sections: [TokensManageGroupSection],
        expandedIds: Set<String>,
        locale: Locale
    ) -> [TokensManageSection] {
        sections.map { section in
            TokensManageSection(
                kind: section.kind,
                title: createTitle(for: section, locale: locale),
                items: section.groups.flatMap {
                    createItems(for: $0, expandedIds: expandedIds, locale: locale)
                }
            )
        }
    }
}
