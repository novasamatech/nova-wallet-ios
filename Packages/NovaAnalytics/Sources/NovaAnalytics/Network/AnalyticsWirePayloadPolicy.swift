import Foundation

enum AnalyticsWirePayloadPolicyError: Error {
    case freeText
}

// Revalidate stored strings before signing to prevent free text from reaching an envelope.
enum AnalyticsWirePayloadPolicy {
    static let grammar = AnalyticsContentGrammar(
        alphabet: AnalyticsContentGrammar.Alphabet.alphanumerics.union(CharacterSet(charactersIn: " ._:-()")),
        lengths: 1 ... 64
    )

    // Generated IDs and declared names and keys need no registry punctuation.
    static let identifierGrammar = AnalyticsContentGrammar(
        alphabet: AnalyticsContentGrammar.Alphabet.alphanumerics.union(CharacterSet(charactersIn: "._-")),
        lengths: 1 ... 64
    )

    static func vet(_ row: AnalyticsPendingEvent) throws -> AnalyticsEventRemote {
        let props = try AnalyticsCoding.decoder.decode([String: AnalyticsWireValue].self, from: row.payload)

        let remote = AnalyticsEventRemote(
            id: row.eventId,
            name: row.name,
            timestamp: ISO8601MillisFormatter.string(from: row.timestamp),
            props: props
        )

        try validate(remote)

        return remote
    }

    static func validate(_ remote: AnalyticsEventRemote) throws {
        let identifiers = [remote.id, remote.name] + Array(remote.props.keys)
        let values = remote.props.values.compactMap(\.storedString)

        guard identifiers.allSatisfy(identifierGrammar.accepts), values.allSatisfy(grammar.accepts) else {
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
