import Foundation

protocol GovernanceTrackViewModelFactoryProtocol {
    func createViewModel(
        from track: GovernanceTrackInfoLocal,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumInfoView.Track
}

extension GovernanceTrackViewModelFactoryProtocol {
    func createViewModels(
        from tracks: [GovernanceTrackInfoLocal],
        chain: ChainModel,
        locale: Locale
    ) -> [ReferendumInfoView.Track] {
        tracks.map { createViewModel(from: $0, chain: chain, locale: locale) }
    }
}

final class GovernanceTrackViewModelFactory {}

extension GovernanceTrackViewModelFactory: GovernanceTrackViewModelFactoryProtocol {
    func createViewModel(
        from track: GovernanceTrackInfoLocal,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumInfoView.Track {
        let type = ReferendumTrackType(rawValue: track.name)

        return ReferendumInfoView.Track(
            title: type?.title(for: locale)?.uppercased() ?? "",
            icon: type?.imageViewModel(for: chain)
        )
    }
}
