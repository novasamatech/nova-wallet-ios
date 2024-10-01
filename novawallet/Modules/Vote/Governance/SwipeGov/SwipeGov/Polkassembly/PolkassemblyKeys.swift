import Foundation

enum PolkassemblyKeys {
    static func getSummaryApiKey() -> String {
        let remoteApiKey = EnviromentVariables.variable(named: "POLKASSEMBLY_SUMMARY_API_KEY") ??
            PolkassemblyApiKeys.summaryApi

        return remoteApiKey.trimmingQuotes()
    }
}
