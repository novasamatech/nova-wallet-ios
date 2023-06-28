import Foundation

@resultBuilder
enum SubqueryFilterBuilder {
    static func buildBlock(_ components: SubqueryFilter...) -> String {
        let joinedFilter = components
            .map { $0.rawSubqueryFilter() }
            .joined(with: .comma)

        return "filter: {\(joinedFilter)}"
    }
}
