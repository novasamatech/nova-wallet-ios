import Foundation

struct EthereumRpcError: Codable {
    let code: Int
    let message: String
}

struct EthereumRpcResponse<T: Codable>: Codable {
    let id: UInt16
    let jsonrpc: String
    let error: EthereumRpcError?
    let result: T?
}
