import Foundation

struct HistoryRewardContext {
    static let validatoryKey = "history.validator.key"
    static let eventIdKey = "history.event.id.key"
    static let eraKey = "history.era.key"

    let validator: String?
    let era: Int?
    let eventId: String
}

extension HistoryRewardContext {
    init(context: [String: String]) {
        validator = context[Self.validatoryKey]

        if let eraString = context[Self.eraKey] {
            era = Int(eraString)
        } else {
            era = nil
        }

        eventId = context[Self.eventIdKey] ?? ""
    }

    func toContext() -> [String: String] {
        var context: [String: String] = [
            Self.eventIdKey: eventId
        ]

        if let validator = validator {
            context[Self.validatoryKey] = validator
        }

        if let era = era {
            context[Self.eraKey] = String(era)
        }

        return context
    }
}
