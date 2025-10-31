import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class SubstrateTransferCommandFactory {
    private lazy var callFactory = SubstrateCallFactory()

    /// Adds a transfer command to the extrinsic builder based on the asset storage info type
    /// - Parameters:
    ///   - builder: The extrinsic builder to add the command to
    ///   - amount: The amount to transfer (concrete value or all)
    ///   - recipient: The recipient's account ID
    ///   - assetStorageInfo: Information about the asset's storage structure
    /// - Returns: A tuple containing the updated builder and the call coding path (if applicable)
    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recipient: AccountId,
        assetStorageInfo: AssetStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        switch assetStorageInfo {
        case let .orml(info), let .ormlHydrationEvm(info):
            return try addingOrmlTransferCommand(
                to: builder,
                amount: amount,
                recipient: recipient,
                tokenStorageInfo: info
            )
        case let .statemine(info):
            return try addingAssetsTransferCommand(
                to: builder,
                amount: amount,
                recipient: recipient,
                info: info
            )
        case let .native(info):
            return try addingNativeTransferCommand(
                to: builder,
                amount: amount,
                recipient: recipient,
                info: info
            )
        case let .equilibrium(extras):
            return try addingEquilibriumTransferCommand(
                to: builder,
                amount: amount,
                recipient: recipient,
                extras: extras
            )
        case .erc20, .evmNative:
            // EVM transfers have a separate flow
            return (builder, nil)
        }
    }
}

// MARK: - Private

private extension SubstrateTransferCommandFactory {
    func addingOrmlTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recipient: AccountId,
        tokenStorageInfo: OrmlTokenStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        switch amount {
        case let .concrete(value):
            return try addingOrmlTransferValueCommand(
                to: builder,
                recipient: recipient,
                tokenStorageInfo: tokenStorageInfo,
                value: value
            )
        case let .all(value):
            if tokenStorageInfo.canTransferAll {
                return try addingOrmlTransferAllCommand(
                    to: builder,
                    recipient: recipient,
                    tokenStorageInfo: tokenStorageInfo
                )
            } else {
                return try addingOrmlTransferValueCommand(
                    to: builder,
                    recipient: recipient,
                    tokenStorageInfo: tokenStorageInfo,
                    value: value
                )
            }
        }
    }

    func addingOrmlTransferValueCommand(
        to builder: ExtrinsicBuilderProtocol,
        recipient: AccountId,
        tokenStorageInfo: OrmlTokenStorageInfo,
        value: BigUInt
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.ormlTransfer(
            in: tokenStorageInfo.module,
            currencyId: tokenStorageInfo.currencyId,
            receiverId: recipient,
            amount: value
        )

        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingOrmlTransferAllCommand(
        to builder: ExtrinsicBuilderProtocol,
        recipient: AccountId,
        tokenStorageInfo: OrmlTokenStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.ormlTransferAll(
            in: tokenStorageInfo.module,
            currencyId: tokenStorageInfo.currencyId,
            receiverId: recipient
        )

        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingNativeTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recipient: AccountId,
        info: NativeTokenStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        switch amount {
        case let .concrete(value):
            return try addingNativeTransferValueCommand(
                to: builder,
                recipient: recipient,
                value: value,
                callPath: info.transferCallPath
            )
        case let .all(value):
            if info.canTransferAll {
                return try addingNativeTransferAllCommand(to: builder, recipient: recipient)
            } else {
                return try addingNativeTransferValueCommand(
                    to: builder,
                    recipient: recipient,
                    value: value,
                    callPath: info.transferCallPath
                )
            }
        }
    }

    func addingNativeTransferValueCommand(
        to builder: ExtrinsicBuilderProtocol,
        recipient: AccountId,
        value: BigUInt,
        callPath: CallCodingPath
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.nativeTransfer(to: recipient, amount: value, callPath: callPath)
        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingNativeTransferAllCommand(
        to builder: ExtrinsicBuilderProtocol,
        recipient: AccountId
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.nativeTransferAll(to: recipient)
        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingAssetsTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recipient: AccountId,
        info: AssetsPalletStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.assetsTransfer(
            to: recipient,
            info: info,
            amount: amount.value
        )

        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingEquilibriumTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recipient: AccountId,
        extras: EquilibriumAssetExtras
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.equilibriumTransfer(
            to: recipient,
            extras: extras,
            amount: amount.value
        )

        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }
}
