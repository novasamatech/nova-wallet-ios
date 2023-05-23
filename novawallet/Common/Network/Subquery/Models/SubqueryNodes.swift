import Foundation

struct SubqueryNodes<T>: Decodable where T: Decodable {
    let nodes: [T]
}
