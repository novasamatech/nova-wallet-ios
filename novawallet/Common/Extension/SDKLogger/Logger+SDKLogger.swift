import SDKLogger

/// `substrate-sdk-ios` 5 and Operation-iOS 3 log through logger-ios, whose requirements take the message
/// lazily. `Logger` formats eagerly, so the closures are evaluated on the spot and handed to the app's
/// own `LoggerProtocol` methods. SwiftyBeaver serialises its destinations itself, hence `@unchecked Sendable`.
extension Logger: SDKLogger.SDKLoggerProtocol, @unchecked Sendable {
    func verbose(message: () -> String, file: String, function: String, line: Int) {
        verbose(message: message(), file: file, function: function, line: line)
    }

    func debug(message: () -> String, file: String, function: String, line: Int) {
        debug(message: message(), file: file, function: function, line: line)
    }

    func info(message: () -> String, file: String, function: String, line: Int) {
        info(message: message(), file: file, function: function, line: line)
    }

    func warning(message: () -> String, file: String, function: String, line: Int) {
        warning(message: message(), file: file, function: function, line: line)
    }

    func error(message: () -> String, file: String, function: String, line: Int) {
        error(message: message(), file: file, function: function, line: line)
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
