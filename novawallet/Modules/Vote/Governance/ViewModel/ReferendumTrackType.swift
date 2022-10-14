import Foundation
import UIKit

enum ReferendumTrackType: String, CaseIterable, Equatable {
    case root
    case whiteListedCaller = "whitelisted_caller"
    case stakingAdmin = "staking_admin"
    case treasurer
    case leaseAdmin = "lease_admin"
    case fellowshipAdmin = "fellowship_admin"
    case generalAdmin = "general_admin"
    case auctionAdmin = "auction_admin"
    case referendumCanceller = "referendum_canceller"
    case referendumKiller = "referendum_killer"
    case smallTipper = "small_tipper"
    case bigTipper = "big_tipper"
    case smallSpender = "small_spender"
    case mediumSpender = "medium_spender"
    case bigSpender = "big_spender"

    var priority: UInt {
        let index = Self.allCases.firstIndex(of: self)
        return UInt(index ?? 0)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func title(for locale: Locale) -> String? {
        switch self {
        case .root:
            return R.string.localizable.govTrackRoot(preferredLanguages: locale.rLanguages)
        case .whiteListedCaller:
            return R.string.localizable.govTrackWhitelistedCaller(preferredLanguages: locale.rLanguages)
        case .stakingAdmin:
            return R.string.localizable.govTrackStakingAdmin(preferredLanguages: locale.rLanguages)
        case .treasurer:
            return R.string.localizable.govTrackTreasurer(preferredLanguages: locale.rLanguages)
        case .leaseAdmin:
            return R.string.localizable.govTrackLeaseAdmin(preferredLanguages: locale.rLanguages)
        case .fellowshipAdmin:
            return R.string.localizable.govTrackFellowshipAdmin(preferredLanguages: locale.rLanguages)
        case .generalAdmin:
            return R.string.localizable.govTrackGeneralAdmin(preferredLanguages: locale.rLanguages)
        case .auctionAdmin:
            return R.string.localizable.govTrackAuctionAdmin(preferredLanguages: locale.rLanguages)
        case .referendumCanceller:
            return R.string.localizable.govTrackReferendumCanceller(preferredLanguages: locale.rLanguages)
        case .referendumKiller:
            return R.string.localizable.govTrackReferendumKiller(preferredLanguages: locale.rLanguages)
        case .smallTipper:
            return R.string.localizable.govTrackSmallTipper(preferredLanguages: locale.rLanguages)
        case .bigTipper:
            return R.string.localizable.govTrackBigTipper(preferredLanguages: locale.rLanguages)
        case .smallSpender:
            return R.string.localizable.govTrackSmallSpender(preferredLanguages: locale.rLanguages)
        case .mediumSpender:
            return R.string.localizable.govTrackMediumSpender(preferredLanguages: locale.rLanguages)
        case .bigSpender:
            return R.string.localizable.govTrackBigSpender(preferredLanguages: locale.rLanguages)
        }
    }

    func imageViewModel(for chain: ChainModel) -> ImageViewModelProtocol? {
        switch self {
        case .root:
            return RemoteImageViewModel(url: chain.utilityAsset()?.icon ?? chain.icon)
        case .whiteListedCaller, .fellowshipAdmin:
            return StaticImageViewModel(image: R.image.iconGovFellowship()!)
        case .auctionAdmin:
            return StaticImageViewModel(image: R.image.iconGovCrowdloan()!)
        case .stakingAdmin:
            return StaticImageViewModel(image: R.image.iconGovStaking()!)
        case .leaseAdmin, .generalAdmin, .referendumCanceller, .referendumKiller:
            return StaticImageViewModel(image: R.image.iconGovGovernance()!)
        case .treasurer, .smallTipper, .bigTipper, .smallSpender, .mediumSpender, .bigSpender:
            return StaticImageViewModel(image: R.image.iconGovTreasury()!)
        }
    }

    static func createViewModel(
        from rawName: String,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumInfoView.Model.Track {
        let type = ReferendumTrackType(rawValue: rawName)
        let title = type?.title(for: locale)?.uppercased() ?? rawName.replacingSnakeCase().uppercased()
        let icon = type?.imageViewModel(for: chain)

        return .init(title: title, icon: icon)
    }
}
