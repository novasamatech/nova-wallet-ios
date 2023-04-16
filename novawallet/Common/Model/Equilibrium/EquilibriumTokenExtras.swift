import Foundation

struct EquilibriumAssetExtras: Codable {
    let assetId: UInt64
    let transfersEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case assetId
        case transfersEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let asset = try container.decode(String.self, forKey: .assetId)

        guard let assetId = UInt64(asset) else {
            throw DecodingError.dataCorruptedError(
                forKey: .assetId,
                in: container,
                debugDescription: "unexpected value"
            )
        }

        self.assetId = assetId
        transfersEnabled = try container.decodeIfPresent(Bool.self, forKey: .transfersEnabled)
    }
}
