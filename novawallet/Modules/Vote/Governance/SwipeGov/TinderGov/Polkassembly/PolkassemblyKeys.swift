import Foundation

enum PolkassemblyKeys {
    static func getSummaryApiKey() -> String? {
        EnviromentVariables.variable(named: "POLKASSEMBLY_SUMMARY_API_KEY") ?? PolkassemblyApiKeys.summaryApi
    }
}
