import Foundation

struct EthereumRpcRequest<P: Codable>: Codable {
    let jsonrpc: String
    let method: String
    let params: P
    let id: UInt16

    init(method: String, params: P) {
        let requestId = UInt16.random(in: 1 ... UInt16.max)

        self.init(version: "2.0", id: requestId, method: method, params: params)
    }

    init(version: String, id: UInt16, method: String, params: P) {
        jsonrpc = version
        self.method = method
        self.params = params
        self.id = id
    }
}

extension EthereumRpcRequest where P == [String] {
    init(method: String) {
        let requestId = UInt16.random(in: 1 ... UInt16.max)

        self.init(version: "2.0", id: requestId, method: method, params: [])
    }
}
