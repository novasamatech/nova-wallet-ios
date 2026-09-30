import Foundation

struct SubtensorSubnetMarket: Equatable {
    let coingeckoId: String
    let weekChangePercent: Decimal?
    let weekSparkline: [Decimal?]
    let lastUpdated: Date?
}

struct SubtensorSubnetMarkets: Equatable {
    let byNetuid: [UInt16: SubtensorSubnetMarket]

    func market(for netuid: UInt16) -> SubtensorSubnetMarket? {
        byNetuid[netuid]
    }
}

extension SubtensorSubnetMarkets: Decodable {
    private struct Coin: Decodable {
        private enum CodingKeys: String, CodingKey {
            case id
            case symbol
            case weekChangePercent = "price_change_percentage_7d_in_currency"
            case weekSparkline = "sparkline_in_7d"
            case lastUpdated = "last_updated"
        }

        private struct Sparkline: Decodable {
            let price: [Decimal?]?
        }

        let id: String?
        let symbol: String?
        let weekChangePercent: Decimal?
        let weekSparkline: [Decimal?]
        let lastUpdated: String?

        init(from decoder: Decoder) throws {
            let container = try? decoder.container(keyedBy: CodingKeys.self)

            id = try? container?.decode(String.self, forKey: .id)
            symbol = try? container?.decode(String.self, forKey: .symbol)
            weekChangePercent = try? container?.decode(Decimal.self, forKey: .weekChangePercent)
            weekSparkline = (try? container?.decode(Sparkline.self, forKey: .weekSparkline))?.price ?? []
            lastUpdated = try? container?.decode(String.self, forKey: .lastUpdated)
        }
    }

    init(from decoder: Decoder) throws {
        let coins = try decoder.singleValueContainer().decode([Coin].self)

        let markets = coins.compactMap { coin -> (UInt16, SubtensorSubnetMarket)? in
            guard
                let netuid = coin.symbol.flatMap(Self.netuid(fromSymbol:)),
                let coingeckoId = coin.id.flatMap(Self.coingeckoId(from:)) else {
                return nil
            }

            let market = SubtensorSubnetMarket(
                coingeckoId: coingeckoId,
                weekChangePercent: coin.weekChangePercent,
                weekSparkline: coin.weekSparkline,
                lastUpdated: coin.lastUpdated.flatMap(Self.date(from:))
            )

            return (netuid, market)
        }

        self.init(byNetuid: Dictionary(markets, uniquingKeysWith: { first, _ in first }))
    }
}

private extension SubtensorSubnetMarkets {
    static let symbolPrefix = "sn"
    static let coingeckoIdCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")

    static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func netuid(fromSymbol symbol: String) -> UInt16? {
        let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard normalized.hasPrefix(symbolPrefix) else {
            return nil
        }

        let digits = normalized.dropFirst(symbolPrefix.count)

        guard !digits.isEmpty, digits.unicodeScalars.allSatisfy({ ("0" ... "9").contains($0) }) else {
            return nil
        }

        return UInt16(digits)
    }

    static func coingeckoId(from rawId: String) -> String? {
        let coingeckoId = rawId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !coingeckoId.isEmpty,
            coingeckoId.unicodeScalars.allSatisfy({ coingeckoIdCharacters.contains($0) }) else {
            return nil
        }

        return coingeckoId
    }

    static func date(from value: String) -> Date? {
        fractionalDateFormatter.date(from: value) ?? dateFormatter.date(from: value)
    }
}
