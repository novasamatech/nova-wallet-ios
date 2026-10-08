import Foundation

struct SubtensorConfig {
    let novaFeeRate: BigRational?
    let subnetLogos: SubtensorSubnetLogos
}

extension SubtensorConfig: Decodable {
    private enum CodingKeys: String, CodingKey {
        case swapFee
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let swapFee = try? container.decodeIfPresent(Decimal.self, forKey: .swapFee)

        novaFeeRate = swapFee.flatMap(Self.rate(from:))
        subnetLogos = try SubtensorSubnetLogos(from: decoder)
    }

    private static func rate(from swapFee: Decimal) -> BigRational? {
        guard swapFee >= 0, swapFee < 1 else {
            return nil
        }

        return BigRational.fraction(from: swapFee)
    }
}
