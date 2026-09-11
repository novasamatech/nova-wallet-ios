import Foundation

public enum BackendAttestationModeResolver {
    /// Profile 2 defines no unattested variant of a protected route, so a device that cannot attest
    /// has nothing to send — in any configuration, Simulator included.
    public static func resolve(isAppAttestSupported: Bool) -> BackendAttestationMode {
        isAppAttestSupported ? .appAttest : .unavailable
    }
}
