import Foundation

extension ConnectionApiKeys {
    static func getKey(by name: String) -> String? {
        switch name {
        case "INFURA_API_KEY":
            return EnviromentVariables.variable(named: "INFURA_API_KEY") ?? Self.infuraApiKey
        default:
            return nil
        }
    }
}
