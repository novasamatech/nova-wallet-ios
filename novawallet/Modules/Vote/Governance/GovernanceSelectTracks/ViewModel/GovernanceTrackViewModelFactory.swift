import Foundation
import SoraFoundation

protocol GovernanceTrackViewModelFactoryProtocol {
    func createViewModel(
        from track: GovernanceTrackInfoLocal,
        chain: ChainModel,
        locale: Locale
    ) -> ReferendumInfoView.Track

    func createTracksRowViewModel(
        from tracks: [GovernanceTrackInfoLocal],
        locale: Locale
    ) -> GovernanceTracksViewModel?
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

final class GovernanceTrackViewModelFactory {
    let quantityFormatter: LocalizableResource<NumberFormatter>

    init(
        quantityFormatter: LocalizableResource<NumberFormatter> = NumberFormatter.quantity.localizableResource()
    ) {
        self.quantityFormatter = quantityFormatter
    }
}

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

    func createTracksRowViewModel(
        from tracks: [GovernanceTrackInfoLocal],
        locale: Locale
    ) -> GovernanceTracksViewModel? {
        guard let firstTrack = tracks.first else {
            return nil
        }

        let trackName = ReferendumTrackType(rawValue: firstTrack.name)?.title(
            for: locale
        )?.firstLetterCapitalized() ?? firstTrack.name

        if tracks.count > 1 {
            let otherTracks = quantityFormatter.value(for: locale).string(
                from: NSNumber(value: tracks.count - 1)
            )

            let details = R.string.localizable.govRemoveVotesTracksFormat(
                trackName,
                otherTracks ?? "",
                preferredLanguages: locale.rLanguages
            )

            return .init(details: details, canExpand: true)
        } else {
            return .init(details: trackName, canExpand: false)
        }
    }
}
