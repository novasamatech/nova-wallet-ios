import Foundation

final class GovernanceTracksSettingsWireframe: GovernanceTracksSettingsWireframeProtocol {
    let completion: SelectTracksClosure

    init(completion: @escaping SelectTracksClosure) {
        self.completion = completion
    }

    func proceed(
        from _: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal],
        totalCount: Int
    ) {
        completion(Set(tracks.map(\.trackId)), totalCount)
    }
}
