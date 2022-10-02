import Foundation

enum MoonbeamKeys {
    static var apiKey: String {
        #if F_RELEASE
            return AcalaKeys.variable(named: "MOONBEAM_API_KEY") ?? MoonbeamCrowdloanCIKeys.apiKey
        #else
            return AcalaKeys.variable(named: "MOONBEAM_TEST_API_KEY") ?? MoonbeamCrowdloanCIKeys.apiTestKey
        #endif
    }

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
