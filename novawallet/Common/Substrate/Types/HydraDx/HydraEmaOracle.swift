import Foundation
import BigInt
import SubstrateSdk

enum HydraEmaOracle {
    static let moduleName = "EmaOracle"

    enum Source {
        static let omnipool = Data("omnipool".utf8)
        static let stableswap = Data("stablesw".utf8)
        static let xyk = Data("hydraxyk".utf8)
    }

    enum Period: Encodable, Hashable {
        static let lastBlockField = "LastBlock"
        static let tenMinutesField = "TenMinutes"

        case lastBlock

        case tenMinutes

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .lastBlock:
                try container.encode(Self.lastBlockField)
            case .tenMinutes:
                try container.encode(Self.tenMinutesField)
            }

            try container.encode(JSON.null)
        }
    }

    struct Ratio: Decodable, Equatable {
        enum CodingKeys: String, CodingKey {
            case numerator = "n"
            case denominator = "d"
        }

        @StringCodable var numerator: BigUInt
        @StringCodable var denominator: BigUInt

        var asBigRational: BigRational {
            .init(numerator: numerator, denominator: denominator)
        }
    }

    struct Entry: Decodable {
        let price: Ratio
        @StringCodable var updatedAt: BlockNumber
    }

    struct StoredEntry: Decodable {
        let entry: Entry

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            entry = try container.decode(Entry.self)
        }
    }

    struct OracleKey: Hashable, NMapKeyStorageKeyProtocol {
        let source: Data
        let lowerAsset: HydraDx.AssetId
        let higherAsset: HydraDx.AssetId
        let period: Period

        func appendSubkey(to encoder: DynamicScaleEncoding, type: String, index: Int) throws {
            switch index {
            case 0:
                try encoder.append(BytesCodable(wrappedValue: source), ofType: type)
            case 1:
                try encoder.append(
                    [StringScaleMapper(value: lowerAsset), StringScaleMapper(value: higherAsset)],
                    ofType: type
                )
            case 2:
                try encoder.append(period, ofType: type)
            default:
                throw CommonError.dataCorruption
            }
        }
    }
}

extension HydraEmaOracle {
    enum Smoothing {
        static let minuteDurationMillis: BlockTime = 60_000
        static let tenMinutesInMinutes: BlockTime = 10

        static func value(forPeriodInBlocks blocks: BlockNumber) -> BigUInt {
            let denominator = BigUInt(max(blocks, 1)) + 1

            let (quotient, remainder) = (BigUInt(1) << 128).quotientAndRemainder(dividingBy: denominator)

            return remainder > denominator / 2 ? quotient + 1 : quotient
        }

        static func tenMinutes(blockTimeMillis: BlockTime) -> BigUInt? {
            guard blockTimeMillis > 0 else {
                return nil
            }

            let minutes = minuteDurationMillis / blockTimeMillis

            return value(forPeriodInBlocks: BlockNumber(tenMinutesInMinutes * minutes))
        }
    }
}
