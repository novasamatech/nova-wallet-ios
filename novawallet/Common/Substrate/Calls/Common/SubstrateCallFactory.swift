import Foundation
import SubstrateSdk
import NovaCrypto
import BigInt

protocol SubstrateCallFactoryProtocol {
    func nativeTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        callPath: CallCodingPath
    ) -> RuntimeCall<TransferCall>

    func nativeTransferAll(to receiver: AccountId) -> RuntimeCall<TransferAllCall>

    func assetsTransfer(
        to receiver: AccountId,
        info: AssetsPalletStorageInfo,
        amount: BigUInt
    ) -> RuntimeCall<PalletAssets.TransferCall>

    func ormlTransfer(
        in moduleName: String,
        currencyId: JSON,
        receiverId: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<OrmlTokensPallet.TransferCall>

    func ormlTransferAll(
        in moduleName: String,
        currencyId: JSON,
        receiverId: AccountId
    ) -> RuntimeCall<OrmlTokensPallet.TransferAllCall>

    func bondExtra(amount: BigUInt) -> RuntimeCall<BondExtraCall>

    func unbond(amount: BigUInt) -> RuntimeCall<UnbondCall>

    func rebond(amount: BigUInt) -> RuntimeCall<RebondCall>

    func nominate(targets: [SelectedValidatorInfo]) throws -> RuntimeCall<NominateCall>

    func setPayee(for destination: Staking.RewardDestinationArg) -> RuntimeCall<SetPayeeCall>

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall>

    func chill() -> RuntimeCall<NoRuntimeArgs>

    func contribute(
        to paraId: ParaId,
        amount: BigUInt,
        signature: MultiSignature?
    ) -> RuntimeCall<CrowdloanContributeCall>
    func addMemo(to paraId: ParaId, memo: Data) -> RuntimeCall<CrowdloanAddMemo>
    func remark(remark: Data) -> RuntimeCall<SystemRemarkCall>
    func remarkWithEvent(remark: Data) -> RuntimeCall<SystemRemarkCall>
    func rebag(accountId: AccountId, module: String?) -> RuntimeCall<BagList.RebagCall>
    func equilibriumTransfer(
        to receiver: AccountId,
        extras: EquilibriumAssetExtras,
        amount: BigUInt
    ) -> RuntimeCall<EquilibriumTokenTransfer>

    func addProxy(accountId: AccountId, type: Proxy.ProxyType) -> RuntimeCall<Proxy.AddProxyCall>

    func removeProxy(
        accountId: AccountId,
        type: Proxy.ProxyType
    ) -> RuntimeCall<Proxy.RemoveProxyCall>
}

final class SubstrateCallFactory: SubstrateCallFactoryProtocol {
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

    func assetsTransfer(
        to receiver: AccountId,
        info: AssetsPalletStorageInfo,
        amount: BigUInt
    ) -> RuntimeCall<PalletAssets.TransferCall> {
        let args = PalletAssets.TransferCall(assetId: info.assetId, target: .accoundId(receiver), amount: amount)
        let callCodingPath = PalletAssets.assetsTransfer(for: info.palletName)

        return RuntimeCall(
            moduleName: callCodingPath.moduleName,
            callName: callCodingPath.callName,
            args: args
        )
    }

    func equilibriumTransfer(
        to receiver: AccountId,
        extras: EquilibriumAssetExtras,
        amount: BigUInt
    ) -> RuntimeCall<EquilibriumTokenTransfer> {
        let args = EquilibriumTokenTransfer(
            assetId: extras.assetId,
            destinationAccountId: receiver,
            value: amount
        )

        let callCodingPath = CallCodingPath.equilibriumTransfer

        return RuntimeCall(
            moduleName: callCodingPath.moduleName,
            callName: callCodingPath.callName,
            args: args
        )
    }

    func nativeTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        callPath: CallCodingPath
    ) -> RuntimeCall<TransferCall> {
        let args = TransferCall(dest: .accoundId(receiver), value: amount)
        return RuntimeCall(moduleName: callPath.moduleName, callName: callPath.callName, args: args)
    }

    func nativeTransferAll(to receiver: AccountId) -> RuntimeCall<TransferAllCall> {
        let args = TransferAllCall(dest: .accoundId(receiver), keepAlive: false)
        return RuntimeCall(moduleName: "Balances", callName: "transfer_all", args: args)
    }

    func ormlTransfer(
        in moduleName: String,
        currencyId: JSON,
        receiverId: AccountId,
        amount: BigUInt
    ) -> RuntimeCall<OrmlTokensPallet.TransferCall> {
        let args = OrmlTokensPallet.TransferCall(
            dest: .accoundId(receiverId),
            currencyId: currencyId,
            amount: amount
        )

        return RuntimeCall(moduleName: moduleName, callName: "transfer", args: args)
    }

    func ormlTransferAll(
        in moduleName: String,
        currencyId: JSON,
        receiverId: AccountId
    ) -> RuntimeCall<OrmlTokensPallet.TransferAllCall> {
        let args = OrmlTokensPallet.TransferAllCall(
            dest: .accoundId(receiverId),
            currencyId: currencyId,
            keepAlive: false
        )

        return RuntimeCall(moduleName: moduleName, callName: "transfer_all", args: args)
    }

    func setPayee(for destination: Staking.RewardDestinationArg) -> RuntimeCall<SetPayeeCall> {
        let args = SetPayeeCall(payee: destination)
        return RuntimeCall(moduleName: "Staking", callName: "set_payee", args: args)
    }

    func withdrawUnbonded(for numberOfSlashingSpans: UInt32) -> RuntimeCall<WithdrawUnbondedCall> {
        let args = WithdrawUnbondedCall(numberOfSlashingSpans: numberOfSlashingSpans)
        return RuntimeCall(moduleName: "Staking", callName: "withdraw_unbonded", args: args)
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

    func rebag(accountId: AccountId, module: String?) -> RuntimeCall<BagList.RebagCall> {
        let rebagCall = BagList.RebagCall(dislocated: .accoundId(accountId))
        return rebagCall.runtimeCalls.first(where: {
            $0.moduleName == module
        }) ?? rebagCall.defaultRuntimeCall
    }

    func addProxy(accountId: AccountId, type: Proxy.ProxyType) -> RuntimeCall<Proxy.AddProxyCall> {
        let proxyCall = Proxy.AddProxyCall(
            proxy: .accoundId(accountId),
            proxyType: type,
            delay: 0
        )
        return RuntimeCall(moduleName: Proxy.name, callName: "add_proxy", args: proxyCall)
    }

    func removeProxy(
        accountId: AccountId,
        type: Proxy.ProxyType
    ) -> RuntimeCall<Proxy.RemoveProxyCall> {
        let proxyCall = Proxy.RemoveProxyCall(
            proxy: .accoundId(accountId),
            proxyType: type,
            delay: 0
        )
        return RuntimeCall(moduleName: Proxy.name, callName: "remove_proxy", args: proxyCall)
    }
}

extension SubstrateCallFactory {
    func setRewardDestination(
        _ rewardDestination: RewardDestination<AccountAddress>,
        stashItem: StashItem
    ) throws -> RuntimeCall<SetPayeeCall> {
        let arg: Staking.RewardDestinationArg = try {
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
