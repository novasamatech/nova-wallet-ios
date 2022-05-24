import Foundation
import SubstrateSdk
import IrohaCrypto
import BigInt

protocol SubstrateCallFactoryProtocol {
    func nativeTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<TransferCall>

    func assetsTransfer(
        to receiver: AccountId,
        assetId: String,
        amount: BigUInt
    ) -> RuntimeCall<AssetsTransfer>

    func ormlTransfer(
        in moduleName: String,
        currencyId: JSON,
        receiverId: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<OrmlTokenTransfer>

    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<AccountAddress>
    ) throws -> RuntimeCall<BondCall>

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall>

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall>

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall>

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall>

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall>

    func setPayee(for destination: RewardDestinationArg) -> RuntimeCall<SetPayeeCall>

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall>

    func setController(_ controller: AccountAddress) throws -> RuntimeCall<SetControllerCall>

    func chill() -> RuntimeCall<NoRuntimeArgs>

    func contribute(
        to paraId: ParaId,
        amount: BigUInt,
        signature: MultiSignature?
    ) -> RuntimeCall<CrowdloanContributeCall>
    func addMemo(to paraId: ParaId, memo: Data) -> RuntimeCall<CrowdloanAddMemo>
    func remark(remark: Data) -> RuntimeCall<SystemRemarkCall>
    func remarkWithEvent(remark: Data) -> RuntimeCall<SystemRemarkCall>
}

final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
    func bond(
        amount: BigUInt,
        controller: String,
        rewardDestination: RewardDestination<String>
    ) throws -> RuntimeCall<BondCall> {
        let controllerId = try controller.toAccountId()

        let destArg: RewardDestinationArg

        switch rewardDestination {
        case .restake:
            destArg = .staked
        case let .payout(address):
            let accountId = try address.toAccountId()
            destArg = .account(accountId)
        }

        let args = BondCall(
            controller: .accoundId(controllerId),
            value: amount,
            payee: destArg
        )

        return RuntimeCall(moduleName: "Staking", callName: "bond", args: args)
    }

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall> {
        let args = BondExtraCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "bond_extra", args: args)
    }

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall> {
        let args = UnbondCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "unbond", args: args)
    }

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall> {
        let args = RebondCall(amount: amount)
        return RuntimeCall(moduleName: "Staking", callName: "rebond", args: args)
    }

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall> {
        let addresses: [MultiAddress] = try targets.map { info in
            let accountId = try info.address.toAccountId()
            return MultiAddress.accoundId(accountId)
        }

        let args = NominateCall(targets: addresses)

        return RuntimeCall(moduleName: "Staking", callName: "nominate", args: args)
    }

    func payout(validatorId: Data, era: EraIndex) throws -> RuntimeCall<PayoutCall> {
        let args = PayoutCall(
            validatorStash: validatorId,
            era: era
        )

        return RuntimeCall(moduleName: "Staking", callName: "payout_stakers", args: args)
    }

    func assetsTransfer(
        to receiver: AccountId,
        assetId: String,
        amount: BigUInt
    ) -> RuntimeCall<AssetsTransfer> {
        let args = AssetsTransfer(assetId: assetId, target: .accoundId(receiver), amount: amount)
        return RuntimeCall(moduleName: "Assets", callName: "transfer", args: args)
    }

    func nativeTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount)
        return RuntimeCall(moduleName: "Balances", callName: "transfer", args: args)
    }

    func ormlTransfer(
        in moduleName: String,
        currencyId: JSON,
        receiverId: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<OrmlTokenTransfer> {
        let args = OrmlTokenTransfer(
            dest: .accoundId(receiverId),
            currencyId: currencyId,
            amount: amount
        )

        return RuntimeCall(moduleName: moduleName, callName: "transfer", args: args)
    }

    func setPayee(for destination: RewardDestinationArg) -> RuntimeCall<SetPayeeCall> {
        let args = SetPayeeCall(payee: destination)
        return RuntimeCall(moduleName: "Staking", callName: "set_payee", args: args)
    }

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall> {
        let args = WithdrawUnbondedCall(numberOfSlashingSpans: numberOfSlashingSpans)
        return RuntimeCall(moduleName: "Staking", callName: "withdraw_unbonded", args: args)
    }

    func setController(_ controller: AccountAddress) throws -> RuntimeCall<SetControllerCall> {
        let controllerId = try controller.toAccountId()
        let args = SetControllerCall(controller: .accoundId(controllerId))
        return RuntimeCall(moduleName: "Staking", callName: "set_controller", args: args)
    }

    func chill() -> RuntimeCall<NoRuntimeArgs> {
        RuntimeCall(moduleName: "Staking", callName: "chill")
    }

    func contribute(
        to paraId: ParaId,
        amount: BigUInt,
        signature: MultiSignature?
    ) -> RuntimeCall<CrowdloanContributeCall> {
        let args = CrowdloanContributeCall(index: paraId, value: amount, signature: signature)
        return RuntimeCall(moduleName: "Crowdloan", callName: "contribute", args: args)
    }

    func addMemo(to paraId: ParaId, memo: Data) -> RuntimeCall<CrowdloanAddMemo> {
        let args = CrowdloanAddMemo(index: paraId, memo: memo)
        return RuntimeCall(moduleName: "Crowdloan", callName: "add_memo", args: args)
    }

    func remark(remark: Data) -> RuntimeCall<SystemRemarkCall> {
        let args = SystemRemarkCall(remark: remark)
        return RuntimeCall(moduleName: "System", callName: "remark", args: args)
    }

    func remarkWithEvent(remark: Data) -> RuntimeCall<SystemRemarkCall> {
        let args = SystemRemarkCall(remark: remark)
        return RuntimeCall(moduleName: "System", callName: "remark_with_event", args: args)
    }
}

extension SubstrateCallFactory {
    func setRewardDestination(
        _ rewardDestination: RewardDestination<AccountAddress>,
        stashItem: StashItem
    ) throws -> RuntimeCall<SetPayeeCall> {
        let arg: RewardDestinationArg = try {
            switch rewardDestination {
            case .restake:
                return .staked
            case let .payout(accountAddress):
                if accountAddress == stashItem.stash {
                    return .stash
                }

                if accountAddress == stashItem.controller {
                    return .controller
                }

                let accountId = try accountAddress.toAccountId()

                return .account(accountId)
            }
        }()

        return setPayee(for: arg)
    }
}
