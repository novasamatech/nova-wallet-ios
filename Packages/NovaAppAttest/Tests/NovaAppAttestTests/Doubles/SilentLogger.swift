import Foundation
import SDKLogger

/// Replaces the app's shared `Logger`, which cannot cross into the package. Nothing here
/// asserts on log output — `BackendAttestationProvider` logs only on the best-effort row
/// delete and on a gateway rejection — so every requirement is a no-op.
final class SilentLogger: SDKLoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}

    func debug(message _: String, file _: String, function _: String, line _: Int) {}

    func info(message _: String, file _: String, function _: String, line _: Int) {}

    func warning(message _: String, file _: String, function _: String, line _: Int) {}

    func error(message _: String, file _: String, function _: String, line _: Int) {}
}
