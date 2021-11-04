import Foundation

enum MoonbeamKeys {
    static var authToken: String =
        AcalaKeys.variable(named: "MOONBEAM_API_KEY") ?? MoonbeamCrowdloanCIKeys.apiKey

    static var authTestToken: String =
        AcalaKeys.variable(named: "MOONBEAM_TEST_API_KEY") ?? MoonbeamCrowdloanCIKeys.apiTestKey

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
