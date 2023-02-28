import Foundation

class GovernanceSelectTracksWireframe: GovernanceSelectTracksWireframeProtocol {
    func proceed(
        from _: ControllerBackedProtocol?,
        tracks _: [GovernanceTrackInfoLocal]
    ) {
        fatalError("Must be implemented by child class")
    }
}
