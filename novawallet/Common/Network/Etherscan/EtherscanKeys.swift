import Foundation

enum EtherscanKeys {
    static func getApiKey(for chainId: String) -> String? {
        switch chainId {
        case "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d":
            return Self.variable(named: "MOONBEAM_HISTORY_API_KEY") ?? MoonscanCIKeys.moonbeamApiKey
        case "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b":
            return Self.variable(named: "MOONRIVER_HISTORY_API_KEY") ?? MoonscanCIKeys.moonriverApiKey
        default:
            return nil
        }
    }

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
