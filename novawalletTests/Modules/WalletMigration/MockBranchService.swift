import Foundation
@testable import novawallet

final class MockBranchService {
    private(set) var isActive = false
    private(set) var lastHandledURL: URL?
}

extension MockBranchService: BranchLinkServiceProtocol {
    func canHandle(url _: URL) -> Bool {
        true
    }

    func setup() {
        isActive = true
    }

    func handle(url: URL) {
        guard isActive else {
            return
        }

        lastHandledURL = url
    }
}
