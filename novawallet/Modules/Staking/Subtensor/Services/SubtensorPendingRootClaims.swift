import Foundation

protocol SubtensorPendingRootClaimsProtocol: AnyObject {
    func markSigned(coldkey: AccountId, hotkey: AccountId, at date: Date)

    func clear(coldkey: AccountId, hotkey: AccountId)

    func pendingHotkeys(
        for coldkey: AccountId,
        at date: Date,
        claimable: SubtensorRootClaimable?
    ) -> Set<AccountId>
}

final class SubtensorPendingRootClaims {
    enum Constants {
        static let pendingWindow: TimeInterval = 15 * 60
    }

    private struct Key: Hashable {
        let coldkey: AccountId
        let hotkey: AccountId
    }

    private let mutex = NSLock()
    private var signedDates: [Key: Date] = [:]
}

extension SubtensorPendingRootClaims: SubtensorPendingRootClaimsProtocol {
    func markSigned(coldkey: AccountId, hotkey: AccountId, at date: Date) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        signedDates[Key(coldkey: coldkey, hotkey: hotkey)] = date
    }

    func clear(coldkey: AccountId, hotkey: AccountId) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        signedDates[Key(coldkey: coldkey, hotkey: hotkey)] = nil
    }

    func pendingHotkeys(
        for coldkey: AccountId,
        at date: Date,
        claimable: SubtensorRootClaimable?
    ) -> Set<AccountId> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        signedDates = signedDates.filter { key, signedDate in
            guard date.timeIntervalSince(signedDate) < Constants.pendingWindow else {
                return false
            }

            return key.coldkey != coldkey || !Self.isSettled(hotkey: key.hotkey, claimable: claimable)
        }

        return Set(signedDates.keys.filter { $0.coldkey == coldkey }.map(\.hotkey))
    }
}

private extension SubtensorPendingRootClaims {
    static func isSettled(hotkey: AccountId, claimable: SubtensorRootClaimable?) -> Bool {
        guard let claimable, let minimumClaim = claimable.minimumClaim else {
            return false
        }

        return !claimable.previews.contains { preview in
            preview.hotkey == hotkey && SubtensorRootClaimRule.isClaimable(preview, minimumClaim: minimumClaim)
        }
    }
}

struct SubtensorPendingRootClaimMarker {
    let coldkey: AccountId
    let hotkey: AccountId
    let pendingClaims: SubtensorPendingRootClaimsProtocol

    func markSigned() {
        pendingClaims.markSigned(coldkey: coldkey, hotkey: hotkey, at: Date())
    }

    func finish(failedAt stage: SubtensorStakingSubmissionFailure.Stage? = nil) {
        if case .unconfirmed = stage {
            return
        }

        pendingClaims.clear(coldkey: coldkey, hotkey: hotkey)
    }
}

extension SubtensorPendingRootClaimsProtocol {
    func marker(
        for operation: SubtensorStakingOperation,
        coldkey: AccountId
    ) -> SubtensorPendingRootClaimMarker? {
        operation.claimHotkey.map { hotkey in
            SubtensorPendingRootClaimMarker(coldkey: coldkey, hotkey: hotkey, pendingClaims: self)
        }
    }
}
