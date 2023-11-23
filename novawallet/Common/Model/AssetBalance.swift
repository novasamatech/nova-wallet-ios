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
        switch transferrableMode {
        case .regular:
            return freeInPlank > frozenInPlank ? freeInPlank - frozenInPlank : 0
        case .fungibleTrait:
            let locked = frozenInPlank > reservedInPlank ? frozenInPlank - reservedInPlank : 0
            return freeInPlank > locked ? freeInPlank - locked : 0
        }
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
        freeInPlank > frozen ? freeInPlank - frozen : 0
    }
}

extension AssetBalance {
    enum ExistentialDepositCountMode: UInt8 {
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
            blocked: false
        )
    }
}
