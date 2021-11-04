import Foundation

enum AcalaKeys {
    static var authToken: String =
        AcalaKeys.variable(named: "ACALA_AUTH_TOKEN") ?? AcalaCIKeys.authToken

    static var authTestToken: String =
        AcalaKeys.variable(named: "ACALA_TEST_AUTH_TOKEN") ?? AcalaCIKeys.authTestToken

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
