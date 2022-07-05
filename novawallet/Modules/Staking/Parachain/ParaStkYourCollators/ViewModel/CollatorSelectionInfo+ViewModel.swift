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

        if !metadata.topCapacity.isFull || stake > metadata.lowestTopDelegationAmount {
            return .pending
        }

        return .notRewarded
    }
}
