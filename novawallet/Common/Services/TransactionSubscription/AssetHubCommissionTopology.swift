import Foundation
import SubstrateSdk
import BigInt

enum AssetHubDispatchWrapper {
    case proxy
    case multisig(threshold: MultisigPallet.Threshold, approver: AccountId, origin: AccountId, call: JSON)
}

struct AssetHubCommissionedBatch {
    let effectiveSender: AccountId
    let batchCall: AnyRuntimeCall
    let swapCall: AnyRuntimeCall
    let commissionCall: AnyRuntimeCall
    let wrappers: [AssetHubDispatchWrapper]
    let hasUtilityAncestor: Bool
}

enum AssetHubCommissionTopologyError: Error {
    case unsupportedProxyAddress
    case invalidMultisigSignatories
}

enum AssetHubCommissionTopology {
    static func findBatches(
        in call: JSON,
        extrinsicSender: AccountId,
        supportedAssetsPallets: Set<String>,
        context: RuntimeJsonContext?
    ) throws -> [AssetHubCommissionedBatch] {
        try visit(
            call,
            effectiveSender: extrinsicSender,
            supportedAssetsPallets: supportedAssetsPallets,
            context: context,
            wrappers: [],
            hasUtilityAncestor: false
        )
    }

    static func deriveMultisigOrigin(
        sender: AccountId,
        others: [AccountId],
        threshold: MultisigPallet.Threshold
    ) throws -> AccountId {
        let signatories = (others + [sender]).sorted { $0.lexicographicallyPrecedes($1) }

        guard
            !others.isEmpty,
            threshold > 0,
            Int(threshold) <= signatories.count,
            signatories.count < 1 << 30,
            Set(signatories).count == signatories.count,
            signatories.allSatisfy({ $0.count == SubstrateConstants.accountIdLength }),
            others == others.sorted(by: { $0.lexicographicallyPrecedes($1) }) else {
            throw AssetHubCommissionTopologyError.invalidMultisigSignatories
        }

        let encoder = ScaleEncoder()
        encoder.appendRaw(data: Data("modlpy/utilisuba".utf8))
        try BigUInt(signatories.count).encode(scaleEncoder: encoder)
        signatories.forEach { encoder.appendRaw(data: $0) }
        encoder.appendRaw(data: Data(threshold.littleEndianBytes))

        return try encoder.encode().blake2b32()
    }
}

private extension AssetHubCommissionTopology {
    static func visit(
        _ callJson: JSON,
        effectiveSender: AccountId,
        supportedAssetsPallets: Set<String>,
        context: RuntimeJsonContext?,
        wrappers: [AssetHubDispatchWrapper],
        hasUtilityAncestor: Bool
    ) throws -> [AssetHubCommissionedBatch] {
        let call = try ExtrinsicExtraction.getCall(from: callJson, context: context)

        switch call.path {
        case Proxy.ProxyCall.callPath:
            let proxy: Proxy.ProxyCall = try ExtrinsicExtraction.getCallArgs(from: call.args, context: context)

            guard let real = proxy.real.accountId else {
                throw AssetHubCommissionTopologyError.unsupportedProxyAddress
            }

            return try visit(
                proxy.call,
                effectiveSender: real,
                supportedAssetsPallets: supportedAssetsPallets,
                context: context,
                wrappers: wrappers + [.proxy],
                hasUtilityAncestor: hasUtilityAncestor
            )
        case MultisigPallet.asMultiPath:
            let multisig: MultisigPallet.AsMultiCall<JSON> = try ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            )

            return try visitMultisig(
                call: multisig.call,
                signatories: multisig.otherSignatories.map(\.wrappedValue),
                threshold: multisig.threshold,
                effectiveSender: effectiveSender,
                supportedAssetsPallets: supportedAssetsPallets,
                context: context,
                wrappers: wrappers,
                hasUtilityAncestor: hasUtilityAncestor
            )
        case MultisigPallet.asMultiThreshold1Path:
            let multisig: MultisigPallet.AsMultiThreshold1Call<JSON> = try ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            )

            return try visitMultisig(
                call: multisig.call,
                signatories: multisig.otherSignatories.map(\.wrappedValue),
                threshold: 1,
                effectiveSender: effectiveSender,
                supportedAssetsPallets: supportedAssetsPallets,
                context: context,
                wrappers: wrappers,
                hasUtilityAncestor: hasUtilityAncestor
            )
        default:
            return try visitBatch(
                call,
                effectiveSender: effectiveSender,
                supportedAssetsPallets: supportedAssetsPallets,
                context: context,
                wrappers: wrappers,
                hasUtilityAncestor: hasUtilityAncestor
            )
        }
    }

    static func visitMultisig(
        call: JSON,
        signatories: [AccountId],
        threshold: MultisigPallet.Threshold,
        effectiveSender: AccountId,
        supportedAssetsPallets: Set<String>,
        context: RuntimeJsonContext?,
        wrappers: [AssetHubDispatchWrapper],
        hasUtilityAncestor: Bool
    ) throws -> [AssetHubCommissionedBatch] {
        let origin = try deriveMultisigOrigin(
            sender: effectiveSender,
            others: signatories,
            threshold: threshold
        )

        let wrapper = AssetHubDispatchWrapper.multisig(
            threshold: threshold,
            approver: effectiveSender,
            origin: origin,
            call: call
        )

        return try visit(
            call,
            effectiveSender: origin,
            supportedAssetsPallets: supportedAssetsPallets,
            context: context,
            wrappers: wrappers + [wrapper],
            hasUtilityAncestor: hasUtilityAncestor
        )
    }

    static func visitBatch(
        _ call: AnyRuntimeCall,
        effectiveSender: AccountId,
        supportedAssetsPallets: Set<String>,
        context: RuntimeJsonContext?,
        wrappers: [AssetHubDispatchWrapper],
        hasUtilityAncestor: Bool
    ) throws -> [AssetHubCommissionedBatch] {
        guard UtilityPallet.isBatch(path: call.path) else {
            return []
        }

        let batch: UtilityPallet.Call = try ExtrinsicExtraction.getCallArgs(from: call.args, context: context)

        var matches: [AssetHubCommissionedBatch] = []

        if
            call.path == UtilityPallet.batchAllPath,
            batch.calls.count == 2,
            AssetConversionPallet.isSwap(batch.calls[0].path),
            isCollection(batch.calls[1], supportedAssetsPallets: supportedAssetsPallets) {
            matches.append(
                AssetHubCommissionedBatch(
                    effectiveSender: effectiveSender,
                    batchCall: call,
                    swapCall: batch.calls[0],
                    commissionCall: batch.calls[1],
                    wrappers: wrappers,
                    hasUtilityAncestor: hasUtilityAncestor
                )
            )
        }

        for child in batch.calls {
            let childJson = try child.toScaleCompatibleJSON(with: context?.toRawContext())

            matches += try visit(
                childJson,
                effectiveSender: effectiveSender,
                supportedAssetsPallets: supportedAssetsPallets,
                context: context,
                wrappers: wrappers,
                hasUtilityAncestor: true
            )
        }

        return matches
    }

    static func isCollection(_ call: AnyRuntimeCall, supportedAssetsPallets: Set<String>) -> Bool {
        if call.path == .transferKeepAlive {
            return true
        }

        return supportedAssetsPallets.contains(call.moduleName) &&
            call.path == PalletAssets.assetsTransferKeepAlive(for: call.moduleName)
    }
}
