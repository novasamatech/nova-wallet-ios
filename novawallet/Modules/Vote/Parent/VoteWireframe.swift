import Foundation

final class VoteWireframe {
    let proxySyncService: ProxySyncServiceProtocol

    init(proxySyncService: ProxySyncServiceProtocol) {
        self.proxySyncService = proxySyncService
    }
}

extension VoteWireframe: VoteWireframeProtocol {}
