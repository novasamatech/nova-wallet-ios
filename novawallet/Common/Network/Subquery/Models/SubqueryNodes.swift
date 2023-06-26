import Foundation

struct SubqueryNodes<T>: Decodable where T: Decodable {
    let nodes: [T]
}

struct SubqueryAggregates<T>: Decodable where T: Decodable {
    let groupedAggregates: [T]
}
