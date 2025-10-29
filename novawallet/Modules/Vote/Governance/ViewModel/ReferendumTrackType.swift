import Foundation
import UIKit

enum ReferendumTrackType {
    static let root = "root"
    static let whiteListedCaller = "whitelisted_caller"
    static let stakingAdmin = "staking_admin"
    static let treasurer = "treasurer"
    static let leaseAdmin = "lease_admin"
    static let fellowshipAdmin = "fellowship_admin"
    static let generalAdmin = "general_admin"
    static let auctionAdmin = "auction_admin"
    static let referendumCanceller = "referendum_canceller"
    static let referendumKiller = "referendum_killer"
    static let smallTipper = "small_tipper"
    static let bigTipper = "big_tipper"
    static let smallSpender = "small_spender"
    static let mediumSpender = "medium_spender"
    static let bigSpender = "big_spender"

    static func getPriority(for trackId: String) -> UInt {
        let priorities = [
            Self.root,
            Self.whiteListedCaller,
            Self.stakingAdmin,
            Self.treasurer,
            Self.leaseAdmin,
            Self.fellowshipAdmin,
            Self.generalAdmin,
            Self.auctionAdmin,
            Self.referendumCanceller,
            Self.referendumKiller,
            Self.smallTipper,
            Self.bigTipper,
            Self.smallSpender,
            Self.mediumSpender,
            Self.bigSpender
        ]

        let priority = priorities.firstIndex(of: trackId) ?? 2

        return UInt(priority)
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func title(for trackName: String, locale: Locale) -> String {
        switch trackName {
        case Self.root:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackRoot()
        case Self.whiteListedCaller:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackWhitelistedCaller()
        case Self.stakingAdmin:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackStakingAdmin()
        case Self.treasurer:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackTreasurer()
        case Self.leaseAdmin:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackLeaseAdmin()
        case Self.fellowshipAdmin:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackFellowshipAdmin()
        case Self.generalAdmin:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackGeneralAdmin()
        case Self.auctionAdmin:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackAuctionAdmin()
        case Self.referendumCanceller:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackReferendumCanceller()
        case Self.referendumKiller:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackReferendumKiller()
        case Self.smallTipper:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackSmallTipper()
        case Self.bigTipper:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackBigTipper()
        case Self.smallSpender:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackSmallSpender()
        case Self.mediumSpender:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackMediumSpender()
        case Self.bigSpender:
            return R.string(preferredLanguages: locale.rLanguages).localizable.govTrackBigSpender()
        default:
            return trackName.replacingSnakeCase()
        }
    }

    static func imageViewModel(
        for trackName: String,
        chain: ChainModel
    ) -> ImageViewModelProtocol? {
        switch trackName {
        case Self.root:
            return AssetIconViewModelFactory().createAssetIconViewModel(
                for: chain.utilityAsset()?.icon,
                with: .white
            )
        case Self.whiteListedCaller, Self.fellowshipAdmin:
            return StaticImageViewModel(image: R.image.iconGovFellowship()!)
        case Self.auctionAdmin:
            return StaticImageViewModel(image: R.image.iconGovCrowdloan()!)
        case Self.stakingAdmin:
            return StaticImageViewModel(image: R.image.iconGovStaking()!)
        case Self.leaseAdmin, Self.generalAdmin, Self.referendumCanceller, Self.referendumKiller:
            return StaticImageViewModel(image: R.image.iconGovGovernance()!)
        case
            Self.treasurer,
            Self.smallTipper,
            Self.bigTipper,
            Self.smallSpender,
            Self.mediumSpender,
            Self.bigSpender:
            return StaticImageViewModel(image: R.image.iconGovTreasury()!)
        default:
            return StaticImageViewModel(image: R.image.iconGovUniversalTrack()!)
        }
    }

    static func createViewModel(
        from trackName: String,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumInfoView.Track {
        let title = title(for: trackName, locale: locale).uppercased()
        let icon = imageViewModel(for: trackName, chain: chain)

        return .init(title: title, icon: icon)
    }
}
