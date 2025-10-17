import Foundation
import Foundation_iOS

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
        ReferendumInfoView.Track(
            title: ReferendumTrackType.title(for: track.name, locale: locale).uppercased(),
            icon: ReferendumTrackType.imageViewModel(for: track.name, chain: chain)
        )
    }

    func createTracksRowViewModel(
        from tracks: [GovernanceTrackInfoLocal],
        locale: Locale
    ) -> GovernanceTracksViewModel? {
        guard let firstTrack = tracks.first else {
            return nil
        }

        let trackName = ReferendumTrackType.title(
            for: firstTrack.name,
            locale: locale
        ).firstLetterCapitalized()

        if tracks.count > 1 {
            let otherTracks = quantityFormatter.value(for: locale).string(
                from: NSNumber(value: tracks.count - 1)
            )

            let details = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonMoreFormat(trackName, otherTracks ?? "")

            return .init(details: details, canExpand: true)
        } else {
            return .init(details: trackName, canExpand: false)
        }
    }
}
