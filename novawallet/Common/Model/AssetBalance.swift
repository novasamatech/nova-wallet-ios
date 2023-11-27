import Foundation
import BigInt
import RobinHood

struct AssetBalance: Equatable {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let freeInPlank: BigUInt
    let reservedInPlank: BigUInt
    let frozenInPlank: BigUInt
    let edCountMode: ExistentialDepositCountMode
    let transferrableMode: TransferrableMode
    let blocked: Bool

    var totalInPlank: BigUInt { freeInPlank + reservedInPlank }

    var transferable: BigUInt {
        Self.transferrableBalance(
            from: freeInPlank,
            frozen: frozenInPlank,
            reserved: reservedInPlank,
            mode: transferrableMode
        )
    }

    var locked: BigUInt { frozenInPlank + reservedInPlank }

    var balanceCountingEd: BigUInt {
        switch edCountMode {
        case .basedOnTotal:
            return totalInPlank
        case .basedOnFree:
            return freeInPlank
        }
    }

    func newTransferable(for frozen: BigUInt) -> BigUInt {
        Self.transferrableBalance(
            from: freeInPlank,
            frozen: frozen,
            reserved: reservedInPlank,
            mode: transferrableMode
        )
    }

    static func transferrableBalance(
        from free: BigUInt,
        frozen: BigUInt,
        reserved: BigUInt,
        mode: TransferrableMode
    ) -> BigUInt {
        switch mode {
        case .regular:
            return free > frozen ? free - frozen : 0
        case .fungibleTrait:
            let locked = frozen > reserved ? frozen - reserved : 0
            return free > locked ? free - locked : 0
        }
    }
}

extension AssetBalance {
    enum ExistentialDepositCountMode {
        case basedOnTotal
        case basedOnFree
    }

    enum TransferrableMode {
        case regular
        case fungibleTrait
    }
}

extension AssetBalance: Identifiable {
    static func createIdentifier(for chainAssetId: ChainAssetId, accountId: AccountId) -> String {
        let data = (chainAssetId.stringValue + "-\(accountId.toHex())").data(using: .utf8)
        return data!.sha256().toHex()
    }

    var identifier: String { Self.createIdentifier(for: chainAssetId, accountId: accountId) }

    static func createZero(for chainAssetId: ChainAssetId, accountId: AccountId) -> AssetBalance {
        AssetBalance(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: 0,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )
    }
}
