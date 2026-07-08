import Foundation

struct StakingNotice: Equatable {
    enum Severity: String, Decodable, Equatable {
        case info
        case critical
    }

    let chainId: ChainModel.Id
    let severity: Severity
    let shortText: String
    let longText: String
    let endDate: Date?
}

extension CodingUserInfoKey {
    /// Identifier of the locale to prefer when resolving `shortText` / `longText`
    /// locale-map entries. e.g. "en_US", "pt_PT", "zh_Hans_CN".
    /// If absent, the decoder falls back directly to `"en"`.
    static let stakingNoticePreferredLocale = CodingUserInfoKey(rawValue: "stakingNoticePreferredLocale")!
}

/// Decodes a single notice from the JSON document `nova-utils/notices/staking_notices.json`.
///
/// v1 schema accepts `shortText` / `longText` as plain strings.
/// v2 accepts locale-map objects (`{"en": "...", "ru": "..."}`). The decoder reads the
/// preferred locale from `decoder.userInfo[.stakingNoticePreferredLocale]` if set, and tries
/// progressively shorter forms (e.g. `pt-PT` → `pt`), falling back to `en` if nothing matches.
/// `en` is required in every locale map — a map missing it is rejected.
extension StakingNotice: Decodable {
    private enum CodingKeys: String, CodingKey {
        case chainId
        case severity
        case shortText
        case longText
        case endDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        chainId = try container.decode(ChainModel.Id.self, forKey: .chainId)
        severity = try container.decode(Severity.self, forKey: .severity)
        shortText = try Self.decodeLocalized(decoder: decoder, container: container, key: .shortText)
        longText = try Self.decodeLocalized(decoder: decoder, container: container, key: .longText)

        if let endDateString = try container.decodeIfPresent(String.self, forKey: .endDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            guard let date = formatter.date(from: endDateString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .endDate,
                    in: container,
                    debugDescription: "Expected ISO-8601 date (YYYY-MM-DD), got \(endDateString)"
                )
            }
            endDate = date
        } else {
            endDate = nil
        }
    }

    private static func decodeLocalized(
        decoder: Decoder,
        container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> String {
        if let plain = try? container.decode(String.self, forKey: key) {
            return plain
        }
        let localeMap = try container.decode([String: String].self, forKey: key)

        let preferred = decoder.userInfo[.stakingNoticePreferredLocale] as? String
        for candidate in localeCandidates(from: preferred) {
            if let value = localeMap[candidate] {
                return value
            }
        }
        if let englishValue = localeMap["en"] {
            return englishValue
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Locale map for \(key.rawValue) lacks a fallback 'en' entry"
        )
    }

    /// Normalises a locale identifier (e.g. `pt_PT`, `zh_Hans_CN`) into ordered lookup
    /// candidates with progressively shorter region/script components stripped:
    /// `pt_PT` → `["pt-PT", "pt"]`
    /// `zh_Hans_CN` → `["zh-Hans-CN", "zh-Hans", "zh"]`
    /// `en` → `["en"]`
    private static func localeCandidates(from identifier: String?) -> [String] {
        guard let identifier, !identifier.isEmpty else { return [] }
        let normalized = identifier.replacingOccurrences(of: "_", with: "-")
        var candidates: [String] = [normalized]
        var parts = normalized.split(separator: "-").map(String.init)
        while parts.count > 1 {
            parts.removeLast()
            candidates.append(parts.joined(separator: "-"))
        }
        return candidates
    }
}
