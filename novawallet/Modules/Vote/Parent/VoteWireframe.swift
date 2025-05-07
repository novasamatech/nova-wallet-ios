import Foundation

final class VoteWireframe {
    let proxySyncService: DelegatedAccountSyncServiceProtocol

    init(proxySyncService: DelegatedAccountSyncServiceProtocol) {
        self.proxySyncService = proxySyncService
    }
}

extension VoteWireframe: VoteWireframeProtocol {}
