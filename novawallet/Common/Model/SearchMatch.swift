import Foundation

enum SearchMatch<T> {
    case full(T)
    case prefix(T)
    case inclusion(T)

    var item: T {
        switch self {
        case let .full(item):
            return item
        case let .prefix(item):
            return item
        case let .inclusion(item):
            return item
        }
    }

    var isFull: Bool {
        switch self {
        case .full:
            return true
        default:
            return false
        }
    }
}

extension SearchMatch {
    static func matchString(for query: String, recordField: String, record: T) -> SearchMatch<T>? {
        if let match = matchFullString(for: query, recordField: recordField, record: record) {
            return match
        }

        if let match = matchPrefix(for: query, recordField: recordField, record: record) {
            return match
        }

        if let match = matchInclusion(for: query, recordField: recordField, record: record) {
            return match
        }

        return nil
    }

    static func matchFullString(for query: String, recordField: String, record: T) -> SearchMatch<T>? {
        isFullMatch(query: query.lowercased(), field: recordField.lowercased()) ? .full(record) : nil
    }

    static func isFullMatch(query: String, field: String) -> Bool {
        field == query
    }

    static func matchPrefix(for query: String, recordField: String, record: T) -> SearchMatch<T>? {
        isPrefixMatch(query: query.lowercased(), field: recordField.lowercased()) ? .prefix(record) : nil
    }

    static func isPrefixMatch(query: String, field: String) -> Bool {
        field.hasPrefix(query)
    }

    static func matchInclusion(for query: String, recordField: String, record: T) -> SearchMatch<T>? {
        isInclusionMatch(query: query.lowercased(), field: recordField.lowercased()) ? .inclusion(record) : nil
    }

    static func isInclusionMatch(query: String, field: String) -> Bool {
        field.contains(query)
    }
}
