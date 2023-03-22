import Foundation

enum EtherscanKeys {
    static func getApiKey(for chainId: String) -> String? {
        switch chainId {
        case KnowChainId.moonbeam:
            return EnviromentVariables.variable(named: "MOONBEAM_HISTORY_API_KEY") ?? EtherscanCIKeys.moonbeamApiKey
        case KnowChainId.moonriver:
            return EnviromentVariables.variable(named: "MOONRIVER_HISTORY_API_KEY") ?? EtherscanCIKeys.moonriverApiKey
        case KnowChainId.ethereum:
            return EnviromentVariables.variable(named: "ETHERSCAN_HISTORY_API_KEY") ?? EtherscanCIKeys.etherscanApiKey
        default:
            return nil
        }
    }
}
