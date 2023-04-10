import Foundation

// Timeout settings to apply for JSONRPC requests

enum JSONRPCTimeout {
    // it is better to retry with another node then to wait long
    static let withNodeSwitch: Int = 15

    // there is a single node so wait as much as we can
    static let singleNode: Int = 60
}
