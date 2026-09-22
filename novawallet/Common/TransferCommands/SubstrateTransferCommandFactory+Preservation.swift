import Foundation
import SubstrateSdk
import BigInt

enum SubstratePreservingTransferError: Error {
    case concreteAmountRequired
    case unsupportedStorage
}

extension SubstrateTransferCommandFactory {
    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recipient: AccountId,
        assetStorageInfo: AssetStorageInfo,
        preservingAccount: Bool
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard preservingAccount else {
            return try addingTransferCommand(
                to: builder,
                amount: amount,
                recipient: recipient,
                assetStorageInfo: assetStorageInfo
            )
        }

        guard case let .concrete(value) = amount else {
            throw SubstratePreservingTransferError.concreteAmountRequired
        }

        guard let callPath = Self.preservingTransferPath(for: assetStorageInfo) else {
            throw SubstratePreservingTransferError.unsupportedStorage
        }

        switch assetStorageInfo {
        case .native:
            let call = SubstrateCallFactory().nativeTransfer(
                to: recipient,
                amount: value,
                callPath: callPath
            )

            return (try builder.adding(call: call), callPath)
        case let .statemine(info):
            let args = PalletAssets.TransferCall(
                assetId: info.assetId,
                target: .accoundId(recipient),
                amount: value
            )

            let call = RuntimeCall(path: callPath, args: args)

            return (try builder.adding(call: call), callPath)
        case .orml, .ormlHydrationEvm, .erc20, .evmNative, .equilibrium:
            throw SubstratePreservingTransferError.unsupportedStorage
        }
    }

    static func preservingTransferPath(for assetStorageInfo: AssetStorageInfo) -> CallCodingPath? {
        switch assetStorageInfo {
        case .native:
            return .transferKeepAlive
        case let .statemine(info):
            return PalletAssets.assetsTransferKeepAlive(for: info.palletName)
        case .orml, .ormlHydrationEvm, .erc20, .evmNative, .equilibrium:
            return nil
        }
    }
}
