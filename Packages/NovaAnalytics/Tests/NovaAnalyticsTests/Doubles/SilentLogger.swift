import Foundation
import SDKLogger

/// Replaces the app's shared `Logger`, which cannot cross into the package. Nothing here
/// asserts on log output — `AnalyticsService` and `AnalyticsUploader` log only on dropped
/// rows and failed chains — so every requirement is a no-op.
///
/// A duplicate of `NovaAppAttestTests`' double rather than a shared one: two packages'
/// test targets cannot import each other, and neither package ships its doubles.
final class SilentLogger: SDKLoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}

    func debug(message _: String, file _: String, function _: String, line _: Int) {}

    func info(message _: String, file _: String, function _: String, line _: Int) {}

    func warning(message _: String, file _: String, function _: String, line _: Int) {}

    func error(message _: String, file _: String, function _: String, line _: Int) {}
}
