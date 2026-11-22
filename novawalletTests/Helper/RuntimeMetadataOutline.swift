import Foundation
@testable import novawallet
import SubstrateSdk

/// Labels the types of several metadata blobs by structure, so the same type gets the same label in each of
/// them. Metadata v15 and v16 of one runtime number the same types differently, which makes type ids useless
/// for a comparison: a type is labelled by its own description and then refined with the labels of the types
/// it refers to until the labels stop splitting (which also copes with recursive types).
struct RuntimeTypeShapes {
    private struct Shape {
        let description: String
        let references: [SiLookupId]
    }

    private let labels: [[SiLookupId: Int]]

    init(lookups: [RuntimeTypesLookup]) {
        let shapes = lookups.map { lookup in
            lookup.types.reduce(into: [SiLookupId: Shape]()) { $0[$1.identifier] = Self.makeShape(of: $1.type) }
        }

        var labels = shapes.map { $0.mapValues { $0.description.hashValue } }
        var classesCount = Self.countClasses(in: labels)

        while true {
            labels = zip(shapes, labels).map { shapes, current in
                shapes.reduce(into: [SiLookupId: Int]()) { result, shape in
                    var hasher = Hasher()
                    hasher.combine(current[shape.key])
                    shape.value.references.forEach { hasher.combine(current[$0]) }
                    result[shape.key] = hasher.finalize()
                }
            }

            let newClassesCount = Self.countClasses(in: labels)

            guard newClassesCount != classesCount else {
                break
            }

            classesCount = newClassesCount
        }

        self.labels = labels
    }

    /// The label of the type in the lookup with the given position in the list the shapes were built from
    func label(of typeId: SiLookupId, lookupIndex: Int) -> String {
        labels[lookupIndex][typeId].map { String($0) } ?? "unknown type \(typeId)"
    }

    private static func countClasses(in labels: [[SiLookupId: Int]]) -> Int {
        Set(labels.flatMap(\.values)).count
    }

    private static func describe(_ fields: [RuntimeTypeField]) -> String {
        fields.map { "\($0.name ?? "_"):\($0.typeName ?? "_")" }.joined(separator: ",")
    }

    private static func makeShape(of type: RuntimeType) -> Shape {
        let parameters = type.parameters.map { "\($0.name)\($0.type == nil ? "?" : "")" }.joined(separator: ",")
        var references = type.parameters.compactMap(\.type)

        let definition: String

        switch type.typeDefinition {
        case let .composite(composite):
            definition = "composite(\(describe(composite.fields)))"
            references += composite.fields.map(\.type)
        case let .variant(variant):
            let variants = variant.variants.map { "\($0.index)=\($0.name)(\(describe($0.fields)))" }
            definition = "variant(\(variants.joined(separator: ";")))"
            references += variant.variants.flatMap { $0.fields.map(\.type) }
        case let .sequence(sequence):
            definition = "sequence"
            references.append(sequence.type)
        case let .array(array):
            definition = "array(\(array.length))"
            references.append(array.type)
        case let .tuple(tuple):
            definition = "tuple(\(tuple.components.count))"
            references += tuple.components
        case let .primitive(primitive):
            definition = "primitive(\(primitive.rawValue))"
        case let .compact(compact):
            definition = "compact"
            references.append(compact.type)
        case let .bitsequence(bitSequence):
            definition = "bits"
            references += [bitSequence.bitStoreType, bitSequence.bitOrderType]
        }

        return Shape(
            description: "\(type.path.joined(separator: "::"))<\(parameters)>\(definition)",
            references: references
        )
    }
}

/// What a runtime's metadata says, item by item, with every type id replaced by its structural label.
/// Two outlines made together are equal exactly when the metadata describe the same runtime the same way.
enum RuntimeMetadataOutline {
    typealias Items = [String: String]

    static func make(for metadataList: [PostV14RuntimeMetadataProtocol]) throws -> [Items] {
        let shapes = RuntimeTypeShapes(lookups: metadataList.map(\.types))

        return try metadataList.enumerated().map { index, metadata in
            let label: (SiLookupId) -> String = { shapes.label(of: $0, lookupIndex: index) }

            var items = Items()
            addPallets(of: metadata, to: &items, label: label)
            try addExtrinsic(of: metadata, to: &items, label: label)
            addRuntimeApis(of: metadata, to: &items, label: label)

            return items
        }
    }

    /// The keys two outlines disagree on, for a readable failure message
    static func differences(_ lhs: Items, _ rhs: Items) -> [String] {
        Set(lhs.keys).union(rhs.keys).filter { lhs[$0] != rhs[$0] }.sorted()
    }
}

private extension RuntimeMetadataOutline {
    static func addPallets(
        of metadata: PostV14RuntimeMetadataProtocol,
        to items: inout Items,
        label: (SiLookupId) -> String
    ) {
        for pallet in metadata.postV14Pallets {
            let prefix = "pallet/\(pallet.name)"

            items["\(prefix)/index"] = String(pallet.index)
            items["\(prefix)/calls"] = pallet.calls.map { label($0.type) }
            items["\(prefix)/events"] = pallet.events.map { label($0.type) }
            items["\(prefix)/errors"] = pallet.errors.map { label($0.type) }
            items["\(prefix)/storagePrefix"] = pallet.storage?.prefix

            for entry in pallet.storage?.entries ?? [] {
                let type: String

                switch entry.type {
                case let .plain(valueType):
                    type = "plain \(label(valueType))"
                case let .map(map):
                    type = "map \(map.hashers.map { String($0.rawValue) }) \(label(map.key)) \(label(map.value))"
                }

                items["\(prefix)/storage/\(entry.name)"] = [
                    String(entry.modifier.rawValue),
                    type,
                    entry.defaultValue.toHex()
                ].joined(separator: " ")
            }

            for constant in pallet.constants {
                items["\(prefix)/constant/\(constant.name)"] = "\(label(constant.type)) \(constant.value.toHex())"
            }
        }
    }

    static func addExtrinsic(
        of metadata: PostV14RuntimeMetadataProtocol,
        to items: inout Items,
        label: (SiLookupId) -> String
    ) throws {
        // the base extension version is the pipeline of metadata before v16 and of a legacy extrinsic
        let extensions = try metadata.postV14Extrinsic.signedExtensions(
            forExtensionVersion: Extrinsic.Version.baseExtensionVersion
        )

        for (index, transactionExtension) in extensions.enumerated() {
            items["extension/\(index)"] = [
                transactionExtension.identifier,
                label(transactionExtension.type),
                label(transactionExtension.additionalSigned)
            ].joined(separator: " ")
        }

        let extrinsicTypes: [SiLookupId]

        if let metadata = metadata as? RuntimeMetadataV15 {
            let extrinsic = metadata.extrinsic
            extrinsicTypes = [extrinsic.addressType, extrinsic.callType, extrinsic.signatureType]
        } else if let metadata = metadata as? RuntimeMetadataV16 {
            let extrinsic = metadata.extrinsic
            extrinsicTypes = [extrinsic.addressType, extrinsic.callType, extrinsic.signatureType]
        } else {
            extrinsicTypes = []
        }

        items["extrinsic"] = extrinsicTypes.map(label).joined(separator: " ")
    }

    static func addRuntimeApis(
        of metadata: PostV14RuntimeMetadataProtocol,
        to items: inout Items,
        label: (SiLookupId) -> String
    ) {
        let methods: [(String, RuntimeApiMethodMetadata)]

        if let metadata = metadata as? RuntimeMetadataV15 {
            methods = metadata.apis.flatMap { api in api.methods.map { (api.name, $0) } }
        } else if let metadata = metadata as? RuntimeMetadataV16 {
            // through the lookup the app uses, which is what brings v16 methods to the common model
            methods = metadata.apis.flatMap { api in
                api.methods.compactMap { method in
                    metadata.getRuntimeApiMethod(for: api.name, methodName: method.name).map { (api.name, $0.method) }
                }
            }
        } else {
            methods = []
        }

        for (apiName, method) in methods {
            let inputs = method.inputs.map { "\($0.name):\(label($0.paramType))" }.joined(separator: ",")

            items["api/\(apiName)/\(method.name)"] = "(\(inputs)) -> \(label(method.output))"
        }
    }
}
