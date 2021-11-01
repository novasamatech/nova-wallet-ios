import Foundation

enum AcalaKeys {
    static var authToken: String =
        AcalaKeys.variable(named: "ACALA_AUTH_TOKEN") ?? AcalaCIKeys.authToken

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
