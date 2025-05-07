import Foundation

struct RaiseBrandsRequestInfo: Equatable {
    static let defaultPageSize: Int = 50

    let query: String?
    let pageIndex: Int
    let pageSize: Int

    init(
        query: String? = nil,
        pageIndex: Int = 0,
        pageSize: Int = Self.defaultPageSize
    ) {
        self.query = query
        self.pageIndex = pageIndex
        self.pageSize = pageSize
    }

    var isFirstPage: Bool { pageIndex == 0 }
}
