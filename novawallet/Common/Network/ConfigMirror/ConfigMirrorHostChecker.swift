import Foundation

protocol ConfigMirrorHostChecking {
    func check(infraUrl: URL)
}

/// The mirror address is built into the app while the address of the same backend for everything else
/// comes with the global config. Nothing fails when they drift apart: the app keeps reading a host
/// that may be left behind, so the mismatch is at least reported.
struct ConfigMirrorHostChecker {
    let mirrorBaseURL: URL
    let logger: LoggerProtocol
}

extension ConfigMirrorHostChecker: ConfigMirrorHostChecking {
    func check(infraUrl: URL) {
        let mirrorHost = mirrorBaseURL.host?.lowercased()
        let infraHost = infraUrl.host?.lowercased()

        guard mirrorHost != infraHost else {
            return
        }

        logger.error(
            "Config mirror host \(mirrorHost ?? "") differs from infraUrl host \(infraHost ?? "") of the global config"
        )
    }
}
