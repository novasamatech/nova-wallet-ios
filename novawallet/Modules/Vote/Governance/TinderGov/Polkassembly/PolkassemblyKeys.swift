import Foundation

enum PolkassemblyKeys {
    static var summaryApiKey: String {
        PolkassemblyKeys.variable(named: "POLKASSEMBLY_SUMMARY_API_KEY") ?? PolkassemblyApiKeys.summaryApi
    }

    static func variable(named name: String) -> String? {
        let processInfo = ProcessInfo.processInfo
        guard let value = processInfo.environment[name] else {
            return nil
        }
        return value
    }
}
