import Foundation
import BigInt

extension CollatorSelectionInfo {
    func status(for selectedAccountId: AccountId, stake: BigUInt) -> ParaStkDelegationStatus {
        guard let snapshot = snapshot else {
            return .notElected
        }

        if snapshot.delegations.contains(where: { $0.owner == selectedAccountId }) {
            return .rewarded
        }

        if metadata.isStakeShouldBeActive(for: stake) {
            return .pending
        }

        return .notRewarded
    }
}
