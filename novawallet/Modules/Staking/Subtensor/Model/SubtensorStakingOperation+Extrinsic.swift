import Foundation
import SubstrateSdk

extension SubtensorStakingOperation {
    var novaFee: SubtensorNovaFee? {
        switch self {
        case .rootStake, .rootUnstake, .rootUnstakeGroup, .rootClaim:
            nil
        case let .subnetBuy(_, _, _, _, novaFee),
             let .subnetSell(_, _, _, _, _, novaFee),
             let .subnetSellGroup(_, _, _, _, _, novaFee):
            novaFee
        }
    }

    var novaFeeBasis: Balance? {
        switch self {
        case .rootStake, .rootUnstake, .rootUnstakeGroup, .rootClaim:
            nil
        case let .subnetBuy(_, _, grossTao, _, _):
            grossTao
        case let .subnetSell(_, _, _, _, quotedTaoOut, _), let .subnetSellGroup(_, _, _, _, quotedTaoOut, _):
            quotedTaoOut
        }
    }

    func pricing(novaFee: SubtensorNovaFee?) -> SubtensorStakingOperation {
        switch self {
        case .rootStake, .rootUnstake, .rootUnstakeGroup, .rootClaim:
            self
        case let .subnetBuy(hotkey, netuid, grossTao, limitPrice, _):
            .subnetBuy(hotkey: hotkey, netuid: netuid, grossTao: grossTao, limitPrice: limitPrice, novaFee: novaFee)
        case let .subnetSell(hotkey, netuid, alpha, limitPrice, quotedTaoOut, _):
            .subnetSell(
                hotkey: hotkey,
                netuid: netuid,
                alpha: alpha,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut,
                novaFee: novaFee
            )
        case let .subnetSellGroup(exits, partials, netuid, limitPrice, quotedTaoOut, _):
            .subnetSellGroup(
                exits: exits,
                partials: partials,
                netuid: netuid,
                limitPrice: limitPrice,
                quotedTaoOut: quotedTaoOut,
                novaFee: novaFee
            )
        }
    }

    func ensureLimitPolicy() throws {
        switch self {
        case .rootStake, .rootUnstake, .rootClaim:
            return
        case let .rootUnstakeGroup(exits, partials):
            try Self.ensureHotkeyGroup(exits: exits, partials: partials)
        case let .subnetBuy(_, netuid, _, limitPrice, _):
            try Self.ensureSubnetLimit(netuid: netuid, limitPrice: limitPrice)
        case let .subnetSell(_, netuid, _, limitPrice, quotedTaoOut, _):
            try Self.ensureSubnetLimit(netuid: netuid, limitPrice: limitPrice)
            try Self.ensureQuotedTaoOut(quotedTaoOut)
        case let .subnetSellGroup(exits, partials, netuid, limitPrice, quotedTaoOut, _):
            try Self.ensureHotkeyGroup(exits: exits, partials: partials)
            try Self.ensureSubnetLimit(netuid: netuid, limitPrice: limitPrice)
            try Self.ensureQuotedTaoOut(quotedTaoOut)
        }
    }

    func ensureNovaFee(beneficiary: AccountId?) throws {
        guard novaFeeBasis != nil else {
            return
        }

        guard let beneficiary, (novaFee?.beneficiary ?? beneficiary) == beneficiary else {
            throw SubtensorStakingOperationError.novaFeeUnavailable
        }
    }

    func extrinsicBuilderClosure(novaFeeBeneficiary: AccountId?) throws -> ExtrinsicBuilderClosure {
        try ensureLimitPolicy()
        try ensureNovaFee(beneficiary: novaFeeBeneficiary)

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
    static func ensureHotkeyGroup(exits: [AccountId], partials: [SubtensorUnstakeSlice]) throws {
        let hotkeys = exits + partials.map(\.hotkey)

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
        case let .rootUnstakeGroup(exits, partials):
            return try Self.createGroupCalls(exits: exits, partials: partials, netuid: rootNetuid, limitPrice: nil)
        case let .subnetBuy(hotkey, netuid, grossTao, limitPrice, _):
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
        case let .subnetSell(hotkey, netuid, alpha, limitPrice, _, _):
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
        case let .subnetSellGroup(exits, partials, netuid, limitPrice, _, _):
            return try Self.createGroupCalls(exits: exits, partials: partials, netuid: netuid, limitPrice: limitPrice)
        case let .rootClaim(hotkey):
            return [
                Self.addingClosure(SubtensorStakingPallet.ClaimRootWithHotkeyCall(hotkey: hotkey).runtimeCall())
            ]
        }
    }

    static func createGroupCalls(
        exits: [AccountId],
        partials: [SubtensorUnstakeSlice],
        netuid: UInt16,
        limitPrice: Balance?
    ) throws -> [ExtrinsicBuilderClosure] {
        let exitClosures = try exits.map { hotkey in
            try addingClosure(
                SubtensorStakingPallet.RemoveStakeFullLimitCall(hotkey: hotkey, netuid: netuid, limitPrice: limitPrice)
                    .runtimeCall()
            )
        }

        let partialClosures: [ExtrinsicBuilderClosure] = try partials.map { partial in
            if let limitPrice {
                try addingClosure(
                    SubtensorStakingPallet.RemoveStakeLimitCall(
                        hotkey: partial.hotkey,
                        netuid: netuid,
                        amountUnstaked: partial.alpha,
                        limitPrice: limitPrice,
                        allowPartial: false
                    ).runtimeCall()
                )
            } else {
                try addingClosure(
                    SubtensorStakingPallet.RemoveStakeCall(
                        hotkey: partial.hotkey,
                        netuid: netuid,
                        amountUnstaked: partial.alpha
                    ).runtimeCall()
                )
            }
        }

        return exitClosures + partialClosures
    }
}
