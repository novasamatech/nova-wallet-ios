import Foundation
import SDKLogger

final class RecordingLogger: SDKLoggerProtocol {
    enum Level {
        case verbose
        case debug
        case info
        case warning
        case error
    }

    struct Entry: Equatable {
        let level: Level
        let message: String
    }

    private let mutex = NSLock()
    private var recordedEntries: [Entry] = []

    var entries: [Entry] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return recordedEntries
    }

    var warnings: [String] {
        entries.filter { $0.level == .warning }.map(\.message)
    }

    func verbose(message: String, file _: String, function _: String, line _: Int) {
        record(.verbose, message)
    }

    func debug(message: String, file _: String, function _: String, line _: Int) {
        record(.debug, message)
    }

    func info(message: String, file _: String, function _: String, line _: Int) {
        record(.info, message)
    }

    func warning(message: String, file _: String, function _: String, line _: Int) {
        record(.warning, message)
    }

    func error(message: String, file _: String, function _: String, line _: Int) {
        record(.error, message)
    }

    private func record(_ level: Level, _ message: String) {
        mutex.lock()
        recordedEntries.append(Entry(level: level, message: message))
        mutex.unlock()
    }
}
