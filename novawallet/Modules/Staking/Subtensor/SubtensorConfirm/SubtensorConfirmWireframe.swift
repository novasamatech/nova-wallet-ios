import Foundation

final class SubtensorConfirmWireframe: SubtensorConfirmWireframeProtocol {
    let state: SubtensorSharedStateProtocol

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
    }
}
