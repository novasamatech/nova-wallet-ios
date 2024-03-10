import Foundation

extension GovernanceApiKeys {
    func getPolkassemblyApiKey() -> String {
        EnviromentVariables.variable(named: "POLKASSEMBLY_API_KEY") ?? Self.polkassemblyApiKey
    }
}
