import SDKLogger

/// `Logger` already conforms to `SubstrateSdk.SDKLoggerProtocol` in
/// `Common/Extension/SubstrateSdk/Logger+Substrate.swift`. Until the substrate-sdk v5
/// migration lands, that module ships its own identically-named protocol, so `Logger`
/// must satisfy both. Both extensions are empty because `LoggerProtocol` already declares
/// the same five methods.
///
/// On v5, `substrate-sdk-ios` stops declaring the protocol and consumes `logger-ios`
/// instead. Delete `Logger+Substrate.swift` then and keep this file.
extension Logger: SDKLogger.SDKLoggerProtocol {}

/// `SDKLoggerProtocol`'s one-argument convenience methods are `public` in logger-ios, unlike
/// SubstrateSdk's `internal` copy. The moment `Logger` conforms to it (above), those five
/// methods become visible module-wide and collide with the identically-shaped convenience
/// extension the app already declares on its own `LoggerProtocol`
/// (`Common/Logger/Logger.swift`): every `Logger.shared.error("…")`-style call site in the
/// app then has two equally good candidates and fails to compile. Declaring the same five
/// methods directly on the concrete `Logger` type outranks both protocol-extension defaults,
/// so every call site resolves here instead, regardless of how many `SDKLoggerProtocol`-shaped
/// protocols `Logger` conforms to.
///
/// This must survive the v5 migration, not just bridge to it: v5 makes `substrate-sdk-ios`
/// itself consume logger-ios, so the three-way collision (app + SubstrateSdk + logger-ios)
/// becomes a permanent two-way one (app + logger-ios) rather than one migration removes.
extension Logger {
    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        verbose(message: message, file: file, function: function, line: line)
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message: message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message: message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message: message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message: message, file: file, function: function, line: line)
    }
}
