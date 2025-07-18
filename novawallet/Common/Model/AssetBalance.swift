import Foundation
import BigInt
import Operation_iOS

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

    var locked: BigUInt {
        totalInPlank > transferable ? totalInPlank - transferable : 0
    }

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

    func spending(amount: Balance) -> Self {
        .init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: freeInPlank.subtractOrZero(amount),
            reservedInPlank: reservedInPlank,
            frozenInPlank: frozenInPlank,
            edCountMode: edCountMode,
            transferrableMode: transferrableMode,
            blocked: blocked
        )
    }

    func reserving(balance: Balance) -> Self {
        guard freeInPlank >= balance else {
            return self
        }

        return .init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: freeInPlank - balance,
            reservedInPlank: reservedInPlank + balance,
            frozenInPlank: frozenInPlank,
            edCountMode: edCountMode,
            transferrableMode: transferrableMode,
            blocked: blocked
        )
    }

    func regularTransferrableBalance() -> BigUInt {
        Self.transferrableBalance(
            from: freeInPlank,
            frozen: frozenInPlank,
            reserved: reservedInPlank,
            mode: .regular
        )
    }

    func regularReservableBalance(for existentialDeposit: Balance) -> Balance {
        Self.reservableBalance(
            from: freeInPlank,
            frozen: frozenInPlank,
            existentialDeposit: existentialDeposit,
            mode: .regular
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

    static func reservableBalance(
        from free: BigUInt,
        frozen: BigUInt,
        existentialDeposit: BigUInt,
        mode: TransferrableMode
    ) -> BigUInt {
        switch mode {
        case .regular:
            free.subtractOrZero(max(existentialDeposit, frozen))
        case .fungibleTrait:
            free.subtractOrZero(existentialDeposit)
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

extension AssetBalance {
    init(accountInfo: AccountInfo?, chainAssetId: ChainAssetId, accountId: AccountId) {
        self.init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: accountInfo?.data.free ?? 0,
            reservedInPlank: accountInfo?.data.reserved ?? 0,
            frozenInPlank: accountInfo?.data.locked ?? 0,
            edCountMode: accountInfo?.data.edCountMode ?? .basedOnFree,
            transferrableMode: accountInfo?.data.transferrableModel ?? .regular,
            blocked: false
        )
    }

    init(ormlAccount: OrmlAccount?, chainAssetId: ChainAssetId, accountId: AccountId) {
        self.init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: ormlAccount?.free ?? 0,
            reservedInPlank: ormlAccount?.reserved ?? 0,
            frozenInPlank: ormlAccount?.frozen ?? 0,
            edCountMode: .basedOnTotal,
            transferrableMode: .regular,
            blocked: false
        )
    }

    init(
        assetsAccount: PalletAssets.Account?,
        assetsDetails: PalletAssets.Details?,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) {
        let balance = assetsAccount?.balance ?? 0

        let isFrozen = (assetsAccount?.isFrozen ?? false) || (assetsDetails?.isFrozen ?? false)
        let isBlocked = assetsAccount?.isBlocked ?? false

        self.init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: balance,
            reservedInPlank: 0,
            frozenInPlank: isFrozen ? balance : 0,
            edCountMode: .basedOnTotal,
            transferrableMode: .regular,
            blocked: isBlocked
        )
    }

    init(
        eqAccount: EquilibriumAccountInfo?,
        eqReserve: EquilibriumReservedData?,
        eqAssetId: EquilibriumAssetId,
        isUtilityAsset: Bool,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) {
        let frozenInPlank = isUtilityAsset ? eqAccount?.lock ?? .zero : .zero
        let reservedInPlank = eqReserve?.value ?? .zero
        let freeInPlank = eqAccount?.balances
            .first(where: { $0.asset == eqAssetId })?
            .balance.value ?? .zero

        self.init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: freeInPlank,
            reservedInPlank: reservedInPlank,
            frozenInPlank: frozenInPlank,
            edCountMode: .basedOnTotal,
            transferrableMode: .regular,
            blocked: false
        )
    }

    init(evmBalance: Balance, accountId: AccountId, chainAssetId: ChainAssetId) {
        self.init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: evmBalance,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )
    }
}
