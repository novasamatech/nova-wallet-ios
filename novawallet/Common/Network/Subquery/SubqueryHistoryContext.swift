import Foundation

struct SubqueryHistoryContext {
    static let cursorKey = "cursorKey"
    static let isFirstKey = "isFirst"

    var isComplete: Bool { cursor == nil && !isFirst }

    let cursor: String?
    let isFirst: Bool

    init(cursor: String?, isFirst: Bool) {
        self.cursor = cursor
        self.isFirst = isFirst
    }
}

extension SubqueryHistoryContext {
    init(context: [String: String]) {
        cursor = context[Self.cursorKey]

        if let isFirstString = context[Self.isFirstKey] {
            isFirst = Bool(isFirstString) ?? false
        } else {
            isFirst = true
        }
    }

    func toContext() -> [String: String] {
        var context: [String: String] = [:]

        if let cursor = cursor {
            context[Self.cursorKey] = cursor
        }

        context[Self.isFirstKey] = String(isFirst)

        return context
    }
}
