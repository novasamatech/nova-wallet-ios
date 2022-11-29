import Foundation

struct EtherscanHistoryContext {
    static let page = "page"
    static let complete = "isComplete"

    let page: Int?
    let isComplete: Bool
    let defaultOffset: Int

    init(page: Int?, isComplete: Bool, defaultOffset: Int) {
        self.page = page
        self.isComplete = isComplete
        self.defaultOffset = defaultOffset
    }

    init(context: [String: String], defaultOffset: Int) {
        if let pageString = context[Self.page] {
            page = Int(pageString)
        } else {
            page = nil
        }

        if let isCompleteString = context[Self.complete] {
            isComplete = Bool(isCompleteString) ?? false
        } else {
            isComplete = false
        }

        self.defaultOffset = defaultOffset
    }

    func toContext() -> [String: String] {
        var context: [String: String] = [:]

        if let page = page {
            context[Self.page] = String(page)
        }

        context[Self.complete] = String(isComplete)

        return context
    }
}
