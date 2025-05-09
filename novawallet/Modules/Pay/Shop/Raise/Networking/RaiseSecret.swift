import Foundation

enum RaiseSecret {
    static var clientId: String {
        #if F_RELEASE
            EnviromentVariables.variable(named: "RAISE_PRODUCTION_CLIENT_ID") ?? RaiseCIKeys.raiseProductionClientId
        #else
            EnviromentVariables.variable(named: "RAISE_SANDBOX_CLIENT_ID") ?? RaiseApiKeys.raiseSandboxClientId
        #endif
    }

    static var secret: String {
        #if F_RELEASE
            EnviromentVariables.variable(named: "RAISE_PRODUCTION_SECRET") ?? RaiseCIKeys.raiseProductionSecret
        #else
            EnviromentVariables.variable(named: "RAISE_SANDBOX_SECRET") ?? RaiseApiKeys.raiseSandboxSecret
        #endif
    }
}
