import Foundation
import SubstrateSdk
import BigInt

enum AssetHubDispatchWrapper {
    case proxy
    case multisig(threshold: MultisigPallet.Threshold, approver: AccountId, origin: AccountId, call: JSON)
}

struct AssetHubCommissionedBatch {
    let effectiveSender: AccountId
    let swapCall: AnyRuntimeCall
    let commissionCall: AnyRuntimeCall
    let wrappers: [AssetHubDispatchWrapper]
    let hasUtilityAncestor: Bool
}

enum AssetHubCommissionTopologyError: Error {
    case invalidMultisigSignatories
}

enum AssetHubCommissionTopology {
    static func findBatches(
        in call: JSON,
        extrinsicSender: AccountId,
        supportedAssetsPallets: Set<String>,
        context: RuntimeJsonContext?
    ) -> [AssetHubCommissionedBatch] {
        visit(
            call,
            effectiveSender: extrinsicSender,
            supportedAssetsPallets: supportedAssetsPallets,
            context: context,
            wrappers: [],
            hasUtilityAncestor: false
        )
    }

    static func commissionedCalls(
        in batch: UtilityPallet.Call,
        path: CallCodingPath,
        supportedAssetsPallets: Set<String>
    ) -> (swap: AnyRuntimeCall, commission: AnyRuntimeCall)? {
        guard
            path == UtilityPallet.batchAllPath,
            batch.calls.count == 2,
            AssetConversionPallet.isSwap(batch.calls[0].path),
            isCollection(batch.calls[1], supportedAssetsPallets: supportedAssetsPallets) else {
            return nil
        }

        return (swap: batch.calls[0], commission: batch.calls[1])
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
    ) -> [AssetHubCommissionedBatch] {
        guard let call = try? ExtrinsicExtraction.getCall(from: callJson, context: context) else {
            return []
        }

        switch call.path {
        case Proxy.ProxyCall.callPath:
            guard
                let proxy: Proxy.ProxyCall = try? ExtrinsicExtraction.getCallArgs(
                    from: call.args,
                    context: context
                ),
                let real = proxy.real.accountId else {
                return []
            }

            return visit(
                proxy.call,
                effectiveSender: real,
                supportedAssetsPallets: supportedAssetsPallets,
                context: context,
                wrappers: wrappers + [.proxy],
                hasUtilityAncestor: hasUtilityAncestor
            )
        case MultisigPallet.asMultiPath:
            guard let multisig: MultisigPallet.AsMultiCall<JSON> = try? ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            ) else {
                return []
            }

            return visitMultisig(
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
            guard let multisig: MultisigPallet.AsMultiThreshold1Call<JSON> = try? ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            ) else {
                return []
            }

            return visitMultisig(
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
            return visitBatch(
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
    ) -> [AssetHubCommissionedBatch] {
        guard let origin = try? deriveMultisigOrigin(
            sender: effectiveSender,
            others: signatories,
            threshold: threshold
        ) else {
            return []
        }

        let wrapper = AssetHubDispatchWrapper.multisig(
            threshold: threshold,
            approver: effectiveSender,
            origin: origin,
            call: call
        )

        return visit(
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
    ) -> [AssetHubCommissionedBatch] {
        guard
            UtilityPallet.isBatch(path: call.path),
            let batch: UtilityPallet.Call = try? ExtrinsicExtraction.getCallArgs(
                from: call.args,
                context: context
            ) else {
            return []
        }

        var matches: [AssetHubCommissionedBatch] = []

        if let commissioned = commissionedCalls(
            in: batch,
            path: call.path,
            supportedAssetsPallets: supportedAssetsPallets
        ) {
            matches.append(
                AssetHubCommissionedBatch(
                    effectiveSender: effectiveSender,
                    swapCall: commissioned.swap,
                    commissionCall: commissioned.commission,
                    wrappers: wrappers,
                    hasUtilityAncestor: hasUtilityAncestor
                )
            )
        }

        for child in batch.calls {
            guard let childJson = try? child.toScaleCompatibleJSON(with: context?.toRawContext()) else {
                continue
            }

            matches += visit(
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
