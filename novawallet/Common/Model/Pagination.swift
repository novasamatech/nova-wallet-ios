import Foundation

typealias PaginationContext = [String: String]

struct Pagination: Codable, Equatable {
    let context: PaginationContext?
    let count: Int

    init(count: Int, context: [String: String]? = nil) {
        self.count = count
        self.context = context
    }
}
