import SDKLogger

/// `substrate-sdk-ios` 5 and Operation-iOS 3 log through logger-ios, whose requirements take the message
/// lazily. The closure goes on to SwiftyBeaver as it is, which runs it only for a destination that accepts
/// the level: the SDK builds a debug line for every WebSocket frame, and a release build must not pay for it.
/// SwiftyBeaver serialises its destinations itself, hence `@unchecked Sendable`.
extension Logger: SDKLogger.SDKLoggerProtocol, @unchecked Sendable {
    func verbose(message: () -> String, file: String, function: String, line: Int) {
        log.custom(level: .verbose, message: message(), file: file, function: function, line: line)
    }

    func debug(message: () -> String, file: String, function: String, line: Int) {
        log.custom(level: .debug, message: message(), file: file, function: function, line: line)
    }

    func info(message: () -> String, file: String, function: String, line: Int) {
        log.custom(level: .info, message: message(), file: file, function: function, line: line)
    }

    func warning(message: () -> String, file: String, function: String, line: Int) {
        log.custom(level: .warning, message: message(), file: file, function: function, line: line)
    }

    func error(message: () -> String, file: String, function: String, line: Int) {
        log.custom(level: .error, message: message(), file: file, function: function, line: line)
    }
}

/// `SDKLoggerProtocol`'s one-argument convenience methods are `public` in logger-ios. The moment
/// `Logger` conforms to it (above), those five methods become visible module-wide and collide with
/// the identically-shaped convenience extension the app already declares on its own `LoggerProtocol`
/// (`Common/Logger/Logger.swift`): every `Logger.shared.error("…")`-style call site in the
/// app then has two equally good candidates and fails to compile. Declaring the same five
/// methods directly on the concrete `Logger` type outranks both protocol-extension defaults,
/// so every call site resolves here instead.
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
