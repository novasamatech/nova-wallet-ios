struct SystemProperties: Decodable {
    let isEthereum: Bool?
    let ss58Format: UInt16?
    let SS58Prefix: UInt16?
    let tokenDecimals: [UInt16]
    let tokenSymbol: [String]

    enum CodingKeys: String, CodingKey {
        case isEthereum, ss58Format, SS58Prefix, tokenDecimals, tokenSymbol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        isEthereum = try container.decodeIfPresent(Bool.self, forKey: .isEthereum)
        ss58Format = try container.decodeIfPresent(UInt16.self, forKey: .ss58Format)
        SS58Prefix = try container.decodeIfPresent(UInt16.self, forKey: .SS58Prefix)

        do {
            tokenDecimals = try container.decode([UInt16].self, forKey: .tokenDecimals)
        } catch DecodingError.typeMismatch {
            let singleValue = try container.decode(UInt16.self, forKey: .tokenDecimals)
            tokenDecimals = [singleValue]
        }

        do {
            tokenSymbol = try container.decode([String].self, forKey: .tokenSymbol)
        } catch DecodingError.typeMismatch {
            let singleValue = try container.decode(String.self, forKey: .tokenSymbol)
            tokenSymbol = [singleValue]
        }
    }
}
