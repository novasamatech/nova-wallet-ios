import Foundation
import SubstrateSdk

extension SubtensorStakingOperation {
    func ensureLimitPolicy() throws {
        switch self {
        case .rootStake, .rootUnstake, .rootClaim:
            return
        case let .rootUnstakeAll(hotkeys):
            try Self.ensureHotkeyGroup(hotkeys)
        case let .subnetBuy(_, netuid, _, limitPrice):
            try Self.ensureSubnetLimit(netuid: netuid, limitPrice: limitPrice)
        case let .subnetSell(_, netuid, _, limitPrice, quotedTaoOut):
            try Self.ensureSubnetLimit(netuid: netuid, limitPrice: limitPrice)
            try Self.ensureQuotedTaoOut(quotedTaoOut)
        case let .subnetSellAll(hotkeys, netuid, limitPrice, quotedTaoOut):
            try Self.ensureHotkeyGroup(hotkeys)
            try Self.ensureSubnetLimit(netuid: netuid, limitPrice: limitPrice)
            try Self.ensureQuotedTaoOut(quotedTaoOut)
        }
    }

    func extrinsicBuilderClosure(
        feeCalculator: SubtensorNovaFeeCalculator
    ) throws -> ExtrinsicBuilderClosure {
        try ensureLimitPolicy()

        let novaFee = try feeCalculator.novaFee(for: self)
        let stakingCallClosures = try createStakingCallClosures(novaFeeAmount: novaFee?.amount ?? 0)

        let feeTransferClosures: [ExtrinsicBuilderClosure] = novaFee.map { fee in
            let feeTransfer = SubstrateCallFactory().nativeTransfer(
                to: fee.beneficiary,
                amount: fee.amount,
                callPath: .transferKeepAlive
            )

            return [Self.addingClosure(feeTransfer)]
        } ?? []

        let callClosures = stakingCallClosures + feeTransferClosures

        if let singleCallClosure = callClosures.first, callClosures.count == 1 {
            return singleCallClosure
        }

        return { builder in
            try callClosures.reduce(builder.with(batchType: .atomic)) { currentBuilder, callClosure in
                try callClosure(currentBuilder)
            }
        }
    }
}

private extension SubtensorStakingOperation {
    static func ensureHotkeyGroup(_ hotkeys: [AccountId]) throws {
        guard !hotkeys.isEmpty, Set(hotkeys).count == hotkeys.count else {
            throw SubtensorStakingOperationError.invalidHotkeyGroup
        }
    }

    static func ensureSubnetLimit(netuid: UInt16, limitPrice: Balance) throws {
        guard netuid != SubtensorStakingPallet.rootNetuid else {
            throw SubtensorStakingOperationError.limitOnRootOrder
        }

        guard limitPrice > 0 else {
            throw SubtensorStakingOperationError.unprotectedSubnetOrder
        }
    }

    static func ensureQuotedTaoOut(_ quotedTaoOut: Balance) throws {
        guard quotedTaoOut > 0 else {
            throw SubtensorStakingOperationError.unprotectedSubnetOrder
        }
    }

    static func addingClosure<T: Codable>(_ call: RuntimeCall<T>) -> ExtrinsicBuilderClosure {
        { builder in
            try builder.adding(call: call)
        }
    }

    func createStakingCallClosures(novaFeeAmount: Balance) throws -> [ExtrinsicBuilderClosure] {
        let rootNetuid = SubtensorStakingPallet.rootNetuid

        switch self {
        case let .rootStake(hotkey, amount):
            return try [
                Self.addingClosure(
                    SubtensorStakingPallet.AddStakeCall(hotkey: hotkey, netuid: rootNetuid, amountStaked: amount)
                        .runtimeCall()
                )
            ]
        case let .rootUnstake(hotkey, amount):
            return try [
                Self.addingClosure(
                    SubtensorStakingPallet.RemoveStakeCall(hotkey: hotkey, netuid: rootNetuid, amountUnstaked: amount)
                        .runtimeCall()
                )
            ]
        case let .rootUnstakeAll(hotkeys):
            return try Self.createFullExitClosures(hotkeys: hotkeys, netuid: rootNetuid, limitPrice: nil)
        case let .subnetBuy(hotkey, netuid, grossTao, limitPrice):
            return try [
                Self.addingClosure(
                    SubtensorStakingPallet.AddStakeLimitCall(
                        hotkey: hotkey,
                        netuid: netuid,
                        amountStaked: grossTao > novaFeeAmount ? grossTao - novaFeeAmount : 0,
                        limitPrice: limitPrice,
                        allowPartial: false
                    ).runtimeCall()
                )
            ]
        case let .subnetSell(hotkey, netuid, alpha, limitPrice, _):
            return try [
                Self.addingClosure(
                    SubtensorStakingPallet.RemoveStakeLimitCall(
                        hotkey: hotkey,
                        netuid: netuid,
                        amountUnstaked: alpha,
                        limitPrice: limitPrice,
                        allowPartial: false
                    ).runtimeCall()
                )
            ]
        case let .subnetSellAll(hotkeys, netuid, limitPrice, _):
            return try Self.createFullExitClosures(hotkeys: hotkeys, netuid: netuid, limitPrice: limitPrice)
        case let .rootClaim(hotkey):
            return [
                Self.addingClosure(SubtensorStakingPallet.ClaimRootWithHotkeyCall(hotkey: hotkey).runtimeCall())
            ]
        }
    }

    static func createFullExitClosures(
        hotkeys: [AccountId],
        netuid: UInt16,
        limitPrice: Balance?
    ) throws -> [ExtrinsicBuilderClosure] {
        try hotkeys.map { hotkey in
            try addingClosure(
                SubtensorStakingPallet.RemoveStakeFullLimitCall(hotkey: hotkey, netuid: netuid, limitPrice: limitPrice)
                    .runtimeCall()
            )
        }
    }
}
