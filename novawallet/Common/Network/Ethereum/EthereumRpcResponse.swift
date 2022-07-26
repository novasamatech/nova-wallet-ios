import Foundation

struct EthereumRpcError: Codable, Error {
    let code: Int
    let message: String
}

struct EthereumRpcResponse<T: Codable>: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case jsonrpc
        case error
        case result
    }

    let identifier: UInt16
    let jsonrpc: String
    let error: EthereumRpcError?
    let result: T?
}
