import Foundation

struct SubtensorEarnConfig: Decodable, Equatable {
    struct EntryFlags: Equatable {
        let enabled: Bool
        let newBadgeUntil: Date?
    }

    struct SubnetEntry: Equatable {
        let registeredAt: UInt64
        let preferredValidator: AccountId?
        let coingeckoId: String?
        let logo: String?
    }

    let version: Int
    let entry: EntryFlags?
    let headlineMaxAnnualRate: Decimal?
    let preferredRootValidator: AccountId?
    let logoBaseUrl: URL?
    let subnets: [UInt16: SubnetEntry]
    let invalidEntries: [String]

    var isEntryEnabled: Bool {
        entry?.enabled == true
    }

    func subnetEntry(for subnet: SubtensorSubnetRef) -> SubnetEntry? {
        guard
            let subnetEntry = subnets[subnet.netuid],
            subnetEntry.registeredAt == subnet.registeredAt else {
            return nil
        }

        return subnetEntry
    }

    func replacingEntry(_ entry: EntryFlags?) -> SubtensorEarnConfig {
        SubtensorEarnConfig(
            version: version,
            entry: entry,
            headlineMaxAnnualRate: headlineMaxAnnualRate,
            preferredRootValidator: preferredRootValidator,
            logoBaseUrl: logoBaseUrl,
            subnets: subnets,
            invalidEntries: invalidEntries
        )
    }
}

extension SubtensorEarnConfig.EntryFlags: Codable {}

extension SubtensorEarnConfig {
    private enum CodingKeys: String, CodingKey {
        case version
        case entry
        case headlineMaxAnnualRate
        case preferredRootValidator
        case logoBaseUrl
        case subnets
    }

    private enum EntryFlagsCodingKeys: String, CodingKey {
        case enabled
        case newBadgeUntil
    }

    private enum SubnetEntryCodingKeys: String, CodingKey {
        case registeredAt
        case preferredValidator
        case coingeckoId
        case logo
    }

    private struct NetuidCodingKey: CodingKey {
        let stringValue: String

        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var tolerance = SubtensorEarnConfigTolerance()

        let version = try container.decode(Int.self, forKey: .version)

        let entry = Self.decodeEntryFlags(from: container, tolerance: &tolerance)

        let headlineMaxAnnualRate = tolerance.optionalValue(
            of: String.self,
            for: .headlineMaxAnnualRate,
            in: container
        ) { try? BittensorApiDecimal.decimal($0) }

        let preferredRootValidator = tolerance.optionalValue(
            of: String.self,
            for: .preferredRootValidator,
            in: container,
            transform: Self.accountId(from:)
        )

        let logoBaseUrl = tolerance.optionalValue(
            of: String.self,
            for: .logoBaseUrl,
            in: container,
            transform: Self.absoluteUrl(from:)
        )

        let subnets = Self.decodeSubnets(from: container, tolerance: &tolerance)

        self.init(
            version: version,
            entry: entry,
            headlineMaxAnnualRate: headlineMaxAnnualRate,
            preferredRootValidator: preferredRootValidator,
            logoBaseUrl: logoBaseUrl,
            subnets: subnets,
            invalidEntries: tolerance.invalidEntries
        )
    }

    private static func decodeEntryFlags(
        from container: KeyedDecodingContainer<CodingKeys>,
        tolerance: inout SubtensorEarnConfigTolerance
    ) -> EntryFlags? {
        guard container.hasValue(forKey: .entry) else {
            return nil
        }

        guard
            let entryContainer = try? container.nestedContainer(
                keyedBy: EntryFlagsCodingKeys.self,
                forKey: .entry
            ) else {
            tolerance.markInvalid(.entry, in: container)
            return nil
        }

        guard
            let enabled = tolerance.requiredValue(
                of: Bool.self,
                for: .enabled,
                in: entryContainer,
                transform: { $0 }
            ) else {
            return nil
        }

        let newBadgeUntil = tolerance.optionalValue(
            of: FullDateCodable.self,
            for: .newBadgeUntil,
            in: entryContainer
        ) { $0.wrappedValue }

        return EntryFlags(enabled: enabled, newBadgeUntil: newBadgeUntil)
    }

    private static func decodeSubnets(
        from container: KeyedDecodingContainer<CodingKeys>,
        tolerance: inout SubtensorEarnConfigTolerance
    ) -> [UInt16: SubnetEntry] {
        guard container.hasValue(forKey: .subnets) else {
            return [:]
        }

        guard
            let subnetsContainer = try? container.nestedContainer(
                keyedBy: NetuidCodingKey.self,
                forKey: .subnets
            ) else {
            tolerance.markInvalid(.subnets, in: container)
            return [:]
        }

        var subnets: [UInt16: SubnetEntry] = [:]

        for key in subnetsContainer.allKeys.sorted(by: { $0.stringValue < $1.stringValue }) {
            guard
                let netuid = UInt16(key.stringValue),
                String(netuid) == key.stringValue,
                let entryContainer = try? subnetsContainer.nestedContainer(
                    keyedBy: SubnetEntryCodingKeys.self,
                    forKey: key
                ) else {
                tolerance.markInvalid(key, in: subnetsContainer)
                continue
            }

            if let subnetEntry = decodeSubnetEntry(from: entryContainer, tolerance: &tolerance) {
                subnets[netuid] = subnetEntry
            }
        }

        return subnets
    }

    private static func decodeSubnetEntry(
        from container: KeyedDecodingContainer<SubnetEntryCodingKeys>,
        tolerance: inout SubtensorEarnConfigTolerance
    ) -> SubnetEntry? {
        guard
            let registeredAt = tolerance.requiredValue(
                of: UInt64.self,
                for: .registeredAt,
                in: container,
                transform: { $0 }
            ) else {
            return nil
        }

        let preferredValidator = tolerance.optionalValue(
            of: String.self,
            for: .preferredValidator,
            in: container,
            transform: accountId(from:)
        )

        let coingeckoId = tolerance.optionalValue(of: String.self, for: .coingeckoId, in: container) { $0 }

        let logo = tolerance.optionalValue(of: String.self, for: .logo, in: container) { $0 }

        return SubnetEntry(
            registeredAt: registeredAt,
            preferredValidator: preferredValidator,
            coingeckoId: coingeckoId,
            logo: logo
        )
    }

    private static func accountId(from address: AccountAddress) -> AccountId? {
        try? address.toAccountId(using: .defaultSubstrateFormat)
    }

    private static func absoluteUrl(from value: String) -> URL? {
        guard
            let url = URL(string: value),
            url.scheme != nil,
            url.host != nil else {
            return nil
        }

        return url
    }
}

private struct SubtensorEarnConfigTolerance {
    private(set) var invalidEntries: [String] = []

    mutating func markInvalid<Key: CodingKey>(_ key: Key, in container: KeyedDecodingContainer<Key>) {
        let components: [CodingKey] = container.codingPath + [key]

        invalidEntries.append(components.map(\.stringValue).joined(separator: "."))
    }

    mutating func requiredValue<Key: CodingKey, Raw: Decodable, Value>(
        of _: Raw.Type,
        for key: Key,
        in container: KeyedDecodingContainer<Key>,
        transform: (Raw) -> Value?
    ) -> Value? {
        guard
            let raw = try? container.decode(Raw.self, forKey: key),
            let value = transform(raw) else {
            markInvalid(key, in: container)
            return nil
        }

        return value
    }

    mutating func optionalValue<Key: CodingKey, Raw: Decodable, Value>(
        of rawType: Raw.Type,
        for key: Key,
        in container: KeyedDecodingContainer<Key>,
        transform: (Raw) -> Value?
    ) -> Value? {
        guard container.hasValue(forKey: key) else {
            return nil
        }

        return requiredValue(of: rawType, for: key, in: container, transform: transform)
    }
}

private extension KeyedDecodingContainer {
    func hasValue(forKey key: Key) -> Bool {
        contains(key) && (try? decodeNil(forKey: key)) == false
    }
}
