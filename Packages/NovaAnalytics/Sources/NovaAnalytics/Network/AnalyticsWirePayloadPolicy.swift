import Foundation

enum AnalyticsWirePayloadPolicyError: Error {
    case freeText
}

/// The last gate before a body is signed: every string read back from a stored row must fit the
/// boundary grammar, otherwise the row is poison and never reaches an envelope.
enum AnalyticsWirePayloadPolicy {
    static let grammar = AnalyticsContentGrammar(
        alphabet: AnalyticsContentGrammar.Alphabet.alphanumerics.union(CharacterSet(charactersIn: " ._:-")),
        lengths: 1 ... 64
    )

    static func vet(_ row: AnalyticsPendingEvent) throws -> AnalyticsEventRemote {
        let props = try AnalyticsCoding.decoder.decode([String: AnalyticsWireValue].self, from: row.payload)

        let remote = AnalyticsEventRemote(
            id: row.identifier,
            name: row.name,
            timestamp: ISO8601MillisFormatter.string(from: row.timestamp),
            props: props
        )

        try validate(remote)

        return remote
    }

    static func validate(_ remote: AnalyticsEventRemote) throws {
        let strings = [remote.id, remote.name]
            + Array(remote.props.keys)
            + remote.props.values.compactMap(\.storedString)

        guard strings.allSatisfy(grammar.accepts) else {
            throw AnalyticsWirePayloadPolicyError.freeText
        }
    }
}

private extension AnalyticsWireValue {
    var storedString: String? {
        guard case let .string(value) = self else {
            return nil
        }

        return value
    }
}
