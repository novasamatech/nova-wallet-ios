import Foundation
@testable import novawallet

/// Records what a unit under test logs, so a test can assert that a failure left a trace.
final class LoggerSpy: LoggerProtocol {
    enum Level: Equatable {
        case verbose
        case debug
        case info
        case warning
        case error
    }

    struct Record: Equatable {
        let level: Level
        let message: String
    }

    private let lock = NSLock()
    private var storedRecords: [Record] = []

    var records: [Record] {
        lock.lock()
        defer { lock.unlock() }

        return storedRecords
    }

    private func store(_ level: Level, _ message: String) {
        lock.lock()
        storedRecords.append(Record(level: level, message: message))
        lock.unlock()
    }

    func verbose(message: String, file _: String, function _: String, line _: Int) {
        store(.verbose, message)
    }

    func debug(message: String, file _: String, function _: String, line _: Int) {
        store(.debug, message)
    }

    func info(message: String, file _: String, function _: String, line _: Int) {
        store(.info, message)
    }

    func warning(message: String, file _: String, function _: String, line _: Int) {
        store(.warning, message)
    }

    func error(message: String, file _: String, function _: String, line _: Int) {
        store(.error, message)
    }
}
