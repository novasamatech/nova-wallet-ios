import Foundation

final class VoteWireframe {
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol

    init(delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol) {
        self.delegatedAccountSyncService = delegatedAccountSyncService
    }
}

extension VoteWireframe: VoteWireframeProtocol {}
