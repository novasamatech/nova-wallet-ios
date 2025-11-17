import Foundation

struct CrowdloanUnlockItem: Hashable {
    let paraId: ParaId
    let block: BlockNumber
}

struct CrowdloanUnlock {
    let items: Set<CrowdloanUnlockItem>
    let amount: Balance

    init?(contributions: [CrowdloanContribution], blockNumber: BlockNumber) {
        let unlockable = contributions.filter { $0.unlocksAt <= blockNumber }
        let totalAmount = unlockable.totalAmountLocked()

        guard !unlockable.isEmpty, totalAmount > 0 else {
            return nil
        }

        let itemList = unlockable.map { CrowdloanUnlockItem(paraId: $0.paraId, block: $0.unlocksAt) }
        items = Set(itemList)
        amount = totalAmount
    }
}
