import Foundation

enum MercuryoKeys {
    static var secretKey: String =
        MercuryoKeys.variable(named: "MERCURYO_PRODUCTION_SECRET") ?? MercuryoCIKeys.secretKey
    static var testSecretKey: String =
        MercuryoKeys.variable(named: "MERCURYO_TEST_SECRET") ?? MercuryoCIKeys.testSecretKey

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
