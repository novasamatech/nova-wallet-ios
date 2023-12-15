import Foundation
import SubstrateSdk

struct RuntimeAugmentationResult {
    struct AdditionalNodes {
        let nodes: [Node]
        let notMatch: Set<String>

        func adding(node: Node) -> AdditionalNodes {
            .init(nodes: nodes + [node], notMatch: notMatch)
        }

        func adding(notMatchedType: String) -> AdditionalNodes {
            .init(nodes: nodes, notMatch: notMatch.union([notMatchedType]))
        }
    }

    let additionalNodes: AdditionalNodes
}

protocol RuntimeAugmentationFactoryProtocol: AnyObject {
    func createSubstrateAugmentation(for runtime: RuntimeMetadataV14) -> RuntimeAugmentationResult
    func createEthereumBasedAugmentation(for runtime: RuntimeMetadataV14) -> RuntimeAugmentationResult
}

final class RuntimeAugmentationFactory {
    static let uncheckedExtrinsicModuleName = "sp_runtime.UncheckedExtrinsic"

    enum MatchingMode {
        case full
        case lastComponent
        case firstLastComponents
    }

    let typePathSeparator: String

    init(typePathSeparator: String = ".") {
        self.typePathSeparator = typePathSeparator
    }

    private func findPortableType(
        for type: String,
        in metadata: RuntimeMetadataV14,
        mode: MatchingMode
    ) -> PortableType? {
        switch mode {
        case .full:
            let path = type.components(separatedBy: typePathSeparator)
            return metadata.types.types.first(where: { $0.type.path == path })
        case .lastComponent:
            let component = type.components(separatedBy: typePathSeparator).last

            return metadata.types.types.first(where: { $0.type.path.last == component })
        case .firstLastComponents:
            let components = type.components(separatedBy: typePathSeparator)
            let first = components.first
            let last = components.last

            return metadata.types.types.first(
                where: { $0.type.path.first == first && $0.type.path.last == last }
            )
        }
    }

    private func findParameterType(
        for mainType: String,
        parameterName: String,
        in metadata: RuntimeMetadataV14,
        mode: MatchingMode
    ) -> String? {
        guard let type = findPortableType(for: mainType, in: metadata, mode: mode) else {
            return nil
        }

        let lookUpId = type.type.parameters.first(where: { $0.name == parameterName })?.type

        guard let concreteType = metadata.types.types.first(where: { $0.identifier == lookUpId }) else {
            return nil
        }

        return concreteType.type.path.joined(separator: typePathSeparator)
    }

    private func find(type: String, in metadata: RuntimeMetadataV14, mode: MatchingMode) -> String? {
        findPortableType(for: type, in: metadata, mode: mode)?.type.path.joined(separator: typePathSeparator)
    }

    private func addingAdditionalOneOfTo(
        types: [String],
        fromType: String,
        additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14,
        mode: MatchingMode
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        for type in types {
            if let metadataType = find(type: type, in: runtime, mode: mode) {
                let node = AliasNode(typeName: fromType, underlyingTypeName: metadataType)
                return additionalNodes.adding(node: node)
            }
        }

        return additionalNodes.adding(notMatchedType: fromType)
    }

    private func addingAdditionalOneOfFrom(
        types: [String],
        toType: String,
        additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14,
        mode: MatchingMode
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        for type in types {
            if let metadataType = find(type: type, in: runtime, mode: mode) {
                let node = AliasNode(typeName: metadataType, underlyingTypeName: toType)
                return additionalNodes.adding(node: node)
            }
        }

        return additionalNodes.adding(notMatchedType: toType)
    }

    private func addingEventPhaseNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        addingAdditionalOneOfTo(
            types: ["frame_system.Phase"],
            fromType: KnownType.phase.name,
            additionalNodes: additionalNodes,
            runtime: runtime,
            mode: .firstLastComponents
        )
    }

    private func addingSubstrateAddressNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        if let addressType = findParameterType(
            for: Self.uncheckedExtrinsicModuleName,
            parameterName: "Address",
            in: runtime,
            mode: .firstLastComponents
        ) {
            let node = AliasNode(typeName: KnownType.address.name, underlyingTypeName: addressType)
            return additionalNodes.adding(node: node)
        } else {
            return additionalNodes.adding(notMatchedType: KnownType.address.name)
        }
    }

    private func addingEthereumBasedAddressNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        addingAdditionalOneOfTo(
            types: ["AccountId20"],
            fromType: KnownType.address.name,
            additionalNodes: additionalNodes,
            runtime: runtime,
            mode: .lastComponent
        )
    }

    private func addingSubstrateSignatureNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        if let signatureType = findParameterType(
            for: Self.uncheckedExtrinsicModuleName,
            parameterName: "Signature",
            in: runtime,
            mode: .firstLastComponents
        ) {
            let node = AliasNode(typeName: KnownType.signature.name, underlyingTypeName: signatureType)
            return additionalNodes.adding(node: node)
        } else {
            return additionalNodes.adding(notMatchedType: KnownType.signature.name)
        }
    }

    private func addingEthereumBasedSignatureNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime _: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        let node = StructNode(
            typeName: KnownType.signature.name,
            typeMapping: [
                NameNode(name: "r", node: ProxyNode(typeName: GenericType.h256.name)),
                NameNode(name: "s", node: ProxyNode(typeName: GenericType.h256.name)),
                NameNode(name: "v", node: ProxyNode(typeName: PrimitiveType.u8.name))
            ]
        )

        return additionalNodes.adding(node: node)
    }

    private func addingSubstrateAccountIdNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        addingAdditionalOneOfFrom(
            types: ["AccountId32"],
            toType: GenericType.accountId.name,
            additionalNodes: additionalNodes,
            runtime: runtime,
            mode: .lastComponent
        )
    }

    private func addingPalletIdentityDataNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        addingAdditionalOneOfFrom(
            types: ["pallet_identity.Data"],
            toType: GenericType.data.name,
            additionalNodes: additionalNodes,
            runtime: runtime,
            mode: .firstLastComponents
        )
    }

    private func addingRuntimeEventNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        addingAdditionalOneOfFrom(
            types: ["RuntimeEvent", "Event"],
            toType: GenericType.event.name,
            additionalNodes: additionalNodes,
            runtime: runtime,
            mode: .lastComponent
        )
    }

    private func addingRuntimeCallNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        addingAdditionalOneOfFrom(
            types: ["RuntimeCall", "Call"],
            toType: GenericType.call.name,
            additionalNodes: additionalNodes,
            runtime: runtime,
            mode: .lastComponent
        )
    }

    private func addingRuntimeDispatchNode(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        let feeType = StateCallRpc.feeResultType
        let runtimeType = "frame_support.dispatch.DispatchInfo"

        guard
            let portableType = findPortableType(
                for: runtimeType,
                in: runtime,
                mode: .firstLastComponents
            ),
            case let .composite(compositeType) = portableType.type.typeDefinition else {
            return additionalNodes.adding(notMatchedType: feeType)
        }

        guard
            let weightLookupId = compositeType.fields.first(where: { $0.name == "weight" })?.type,
            let weightType = runtime.types.types.first(
                where: { $0.identifier == weightLookupId }
            )?.type.path.joined(separator: typePathSeparator),
            let dispatchClassLookupId = compositeType.fields.first(where: { $0.name == "class" })?.type,
            let dispatchClassType = runtime.types.types.first(
                where: { $0.identifier == dispatchClassLookupId }
            )?.type.path.joined(separator: typePathSeparator) else {
            return additionalNodes.adding(notMatchedType: feeType)
        }

        let node = StructNode(
            typeName: feeType,
            typeMapping: [
                NameNode(name: "weight", node: ProxyNode(typeName: weightType)),
                NameNode(name: "class", node: ProxyNode(typeName: dispatchClassType)),
                NameNode(name: "partialFee", node: ProxyNode(typeName: PrimitiveType.u128.name))
            ]
        )

        return additionalNodes.adding(node: node)
    }

    private func getCommonAdditionalNodes(
        for runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        var additionalNodes = RuntimeAugmentationResult.AdditionalNodes(
            nodes: [
                AliasNode(typeName: KnownType.balance.name, underlyingTypeName: PrimitiveType.u128.name),
                AliasNode(typeName: KnownType.index.name, underlyingTypeName: PrimitiveType.u32.name)
            ],
            notMatch: []
        )

        additionalNodes = addingEventPhaseNode(to: additionalNodes, runtime: runtime)
        additionalNodes = addingRuntimeEventNode(to: additionalNodes, runtime: runtime)
        additionalNodes = addingRuntimeCallNode(to: additionalNodes, runtime: runtime)
        additionalNodes = addingSubstrateAccountIdNode(to: additionalNodes, runtime: runtime)
        additionalNodes = addingPalletIdentityDataNode(to: additionalNodes, runtime: runtime)
        additionalNodes = addingRuntimeDispatchNode(to: additionalNodes, runtime: runtime)

        return additionalNodes
    }

    private func addingSubstrateSpecificNodes(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        var updatedNodes = additionalNodes
        updatedNodes = addingSubstrateAddressNode(to: updatedNodes, runtime: runtime)
        updatedNodes = addingSubstrateSignatureNode(to: updatedNodes, runtime: runtime)

        return updatedNodes
    }

    private func addingEthereumBasedSpecificNodes(
        to additionalNodes: RuntimeAugmentationResult.AdditionalNodes,
        runtime: RuntimeMetadataV14
    ) -> RuntimeAugmentationResult.AdditionalNodes {
        var updatedNodes = additionalNodes
        updatedNodes = addingEthereumBasedAddressNode(to: updatedNodes, runtime: runtime)
        updatedNodes = addingEthereumBasedSignatureNode(to: updatedNodes, runtime: runtime)

        return updatedNodes
    }
}

extension RuntimeAugmentationFactory: RuntimeAugmentationFactoryProtocol {
    func createSubstrateAugmentation(for runtime: RuntimeMetadataV14) -> RuntimeAugmentationResult {
        var additionalNodes = getCommonAdditionalNodes(for: runtime)
        additionalNodes = addingSubstrateSpecificNodes(to: additionalNodes, runtime: runtime)

        return RuntimeAugmentationResult(additionalNodes: additionalNodes)
    }

    func createEthereumBasedAugmentation(for runtime: RuntimeMetadataV14) -> RuntimeAugmentationResult {
        var additionalNodes = getCommonAdditionalNodes(for: runtime)
        additionalNodes = addingEthereumBasedSpecificNodes(to: additionalNodes, runtime: runtime)

        return RuntimeAugmentationResult(additionalNodes: additionalNodes)
    }
}
