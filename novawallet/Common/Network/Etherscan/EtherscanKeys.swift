import Foundation

enum EtherscanKeys {
    static func getApiKey(for chainId: String) -> String? {
        switch chainId {
        case KnowChainId.moonbeam:
            return Self.variable(named: "MOONBEAM_HISTORY_API_KEY") ?? EtherscanCIKeys.moonbeamApiKey
        case KnowChainId.moonriver:
            return Self.variable(named: "MOONRIVER_HISTORY_API_KEY") ?? EtherscanCIKeys.moonriverApiKey
        case KnowChainId.ethereum:
            return Self.variable(named: "ETHERSCAN_HISTORY_API_KEY") ?? EtherscanCIKeys.etherscanApiKey
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
