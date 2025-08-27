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

struct SubqueryGreaterThanOrEqualToFilter<T: SubqueryFilterValue>: SubqueryFilter {
    let fieldName: String
    let value: T

    func rawSubqueryFilter() -> String {
        "\(fieldName): {greaterThanOrEqualTo: \(value.rawSubqueryFilter())}"
    }
}

struct SubqueryLessThanOrEqualToFilter<T: SubqueryFilterValue>: SubqueryFilter {
    let fieldName: String
    let value: T

    func rawSubqueryFilter() -> String {
        "\(fieldName): {lessThanOrEqualTo: \(value.rawSubqueryFilter())}"
    }
}

struct SubqueryValueFilter<T: SubqueryFilterValue>: SubqueryFilter {
    let fieldName: String
    let value: T

    func rawSubqueryFilter() -> String {
        "\(fieldName): \(value.rawSubqueryFilter())"
    }
}

struct SubqueryIsNotNullFilter: SubqueryFilter {
    let fieldName: String

    func rawSubqueryFilter() -> String {
        "\(fieldName): { isNull: false }"
    }
}

struct SubqueryNotFilter: SubqueryFilter {
    let fieldName: String
    let inner: SubqueryFilter

    func rawSubqueryFilter() -> String {
        "not: { \(fieldName): { \(inner.rawSubqueryFilter()) }}"
    }
}

struct SubqueryNotWithCompoundFilter: SubqueryFilter {
    let inner: SubqueryCompoundFilter

    func rawSubqueryFilter() -> String {
        "not: { \(inner.rawSubqueryFilter()) }"
    }
}

struct SubqueryContainsFilter: SubqueryFilter {
    let fieldName: String
    let inner: SubqueryFilter

    func rawSubqueryFilter() -> String {
        "\(fieldName): { contains: { \(inner.rawSubqueryFilter()) } }"
    }
}

struct SubqueryContainsKeyFilter: SubqueryFilter {
    let fieldName: String

    func rawSubqueryFilter() -> String {
        "containsKey: \(fieldName.rawSubqueryFilter())"
    }
}

struct SubqueryFieldInFilter: SubqueryFilter {
    let fieldName: String
    let values: [SubqueryFilterValue]

    func rawSubqueryFilter() -> String {
        let rawValues = values
            .map { $0.rawSubqueryFilter() }
            .joined(with: .commaSpace)

        return "\(fieldName): { in: [\(rawValues)] }"
    }
}

struct SubqueryFieldInnerFilter: SubqueryFilter {
    let fieldName: String
    let innerFilter: SubqueryFilter

    func rawSubqueryFilter() -> String {
        "\(fieldName): { \(innerFilter.rawSubqueryFilter()) }"
    }
}

struct SubqueryIsNullFilter: SubqueryFilter {
    let fieldName: String

    func rawSubqueryFilter() -> String {
        "\(fieldName): { isNull: true }"
    }
}

extension String: SubqueryFilterValue {
    func rawSubqueryFilter() -> String {
        "\"\(self)\""
    }
}

struct SubqueryStringConvertibleValue<T: LosslessStringConvertible>: SubqueryFilterValue {
    let value: T

    func rawSubqueryFilter() -> String {
        "\(value)"
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
