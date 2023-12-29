import Foundation

extension ConnectionApiKeys {
    static func getKey(by name: String) -> String? {
        switch name {
        case "INFURA_API_KEY":
            return EnviromentVariables.variable(named: "INFURA_API_KEY") ?? Self.infuraApiKey
        case "DWELLIR_API_KEY":
            return EnviromentVariables.variable(named: "DWELLIR_API_KEY") ?? Self.dwellirApiKey
        default:
            return nil
        }
    }
}
