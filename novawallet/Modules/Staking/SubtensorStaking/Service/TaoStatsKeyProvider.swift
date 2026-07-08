import Foundation

/// [TEMP-TAOSTATS] Reads the TaoStats API key from a plain-text file at
/// `~/Desktop/tao-ewt-staking/taostats-api-key.txt` at runtime, only in
/// DEBUG builds. Release builds always return nil so the key is never
/// even looked for in production. When Nova's indexer ships, this whole
/// file is deleted and the factory DI wiring drops the TaoStats data
/// source for a Nova one.
enum TaoStatsKeyProvider {
    /// Returns the API key if available, nil otherwise. The caller is
    /// responsible for gracefully degrading (e.g. falling back to a stub
    /// data source that returns zero values) when nil.
    static func loadKey() -> String? {
        #if DEBUG
            // On iOS simulator, `NSHomeDirectory()` returns the sandboxed app
            // container (…/CoreSimulator/Devices/<UUID>/data/Containers/Data
            // /Application/<AppUUID>/), NOT the host Mac user's home. Apple
            // exposes the real host home via the `SIMULATOR_HOST_HOME`
            // environment variable inside the simulator — use that when
            // available so the DEBUG key file at `~/Desktop/...` is actually
            // reachable from inside the running app.
            let hostHome: String
            #if targetEnvironment(simulator)
                hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"]
                    ?? NSHomeDirectory()
            #else
                hostHome = NSHomeDirectory()
            #endif

            let url = URL(fileURLWithPath: hostHome)
                .appendingPathComponent("Desktop")
                .appendingPathComponent("tao-ewt-staking")
                .appendingPathComponent("taostats-api-key.txt")

            guard let data = try? Data(contentsOf: url) else {
                return nil
            }
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text?.isEmpty == false ? text : nil
        #else
            return nil
        #endif
    }
}
