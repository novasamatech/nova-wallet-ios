import Foundation

/// Pure, with injected inputs so the ladder is unit-tested; the flags are read at the
/// factory (.claude/docs/architecture/services-lifecycle.md:151-153).
enum BackendAttestationModeResolver {
    static func resolve(isReleaseBuild: Bool, isAppAttestSupported: Bool) -> BackendAttestationMode {
        if isAppAttestSupported {
            return .appAttest
        }

        // Simulator on a dev build: unsigned requests, which the dev gateway accepts
        // from dev bundle ids. Android's UNATTESTED mode sends no headers either.
        return isReleaseBuild ? .unavailable : .none
    }
}
