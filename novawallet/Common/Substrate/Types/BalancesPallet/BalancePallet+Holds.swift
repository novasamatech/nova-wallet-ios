import Foundation
import SubstrateSdk
import BigInt

extension BalancesPallet {
    struct HoldId: Decodable, Equatable {
        let module: String
        let reason: String

        init(module: String, reason: String) {
            self.module = module
            self.reason = reason
        }

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            module = try unkeyedContainer.decode(String.self)

            var reasonContainer = try unkeyedContainer.nestedUnkeyedContainer()

            reason = try reasonContainer.decode(String.self)
        }
    }

    struct Hold: Decodable {
        enum CodingKeys: String, CodingKey {
            case holdId = "id"
            case amount
        }

        let holdId: HoldId
        @StringCodable var amount: BigUInt
    }
}

extension RuntimeCoderFactoryProtocol {
    func hasBalancesHold(with holdId: BalancesPallet.HoldId) -> Bool {
        guard let storage = metadata.getStorageMetadata(for: BalancesPallet.holdsPath) else {
            return false
        }

        guard
            case let .map(entry) = storage.type,
            let vecNode = getTypeNode(for: entry.value) as? VectorNode,
            let holdNode = getTypeNode(for: vecNode.underlying.typeName) as? StructNode else {
            return false
        }

        guard
            let holdIdNodeType = holdNode.typeMapping.first(where: { $0.name == "id" })?.node.typeName,
            let holdIdNode = getTypeNode(for: holdIdNodeType) as? SiVariantNode else {
            return false
        }

        guard
            let moduleNodeType = holdIdNode.typeMapping.first(
                where: { $0.name == holdId.module }
            )?.node.typeName,
            let moduleNode = getTypeNode(for: moduleNodeType) as? SiVariantNode else {
            return false
        }

        return moduleNode.typeMapping.contains(where: { $0.name == holdId.reason })
    }
}
