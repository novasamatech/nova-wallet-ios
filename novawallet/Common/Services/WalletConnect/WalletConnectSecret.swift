import Foundation

enum WalletConnectSecret {
    static func getProjectId() -> String {
        EnviromentVariables.variable(named: "WC_PROJECT_ID") ?? WalletConnectCISecrets.projectId
    }
}
