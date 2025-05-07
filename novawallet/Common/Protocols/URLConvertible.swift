import Foundation

protocol URLConvertible {
    var url: URL { get }
    var httpMethod: String { get }
    var params: Encodable? { get }
}
