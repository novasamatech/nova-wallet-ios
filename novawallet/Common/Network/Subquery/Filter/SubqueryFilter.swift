import Foundation

protocol SubqueryFilter {
    func rawSubqueryFilter() -> String
}

protocol SubqueryFilterValue {
    func rawSubqueryFilter() -> String
}

struct SubqueryEqualToFilter<T: SubqueryFilterValue>: SubqueryFilter {
    let fieldName: String
    let value: T

    func rawSubqueryFilter() -> String {
        "\(fieldName): {equalTo: \(value.rawSubqueryFilter())}"
    }
}

extension String: SubqueryFilterValue {
    func rawSubqueryFilter() -> String {
        "\"\(self)\""
    }
}

struct SubqueryInnerFilter: SubqueryFilter {
    let inner: SubqueryFilter

    func rawSubqueryFilter() -> String {
        "{\(inner.rawSubqueryFilter())}"
    }
}

struct SubqueryCompoundFilter: SubqueryFilter {
    let name: String
    let innerFilters: [SubqueryFilter]

    func rawSubqueryFilter() -> String {
        let subFilter = innerFilters
            .map { SubqueryInnerFilter(inner: $0).rawSubqueryFilter() }
            .joined(with: .comma)
        return "\(name):[\(subFilter)]"
    }

    static func or(_ innerFilters: [SubqueryFilter]) -> SubqueryCompoundFilter {
        .init(name: "or", innerFilters: innerFilters)
    }

    static func and(_ innerFilters: [SubqueryFilter]) -> SubqueryCompoundFilter {
        .init(name: "and", innerFilters: innerFilters)
    }
}
