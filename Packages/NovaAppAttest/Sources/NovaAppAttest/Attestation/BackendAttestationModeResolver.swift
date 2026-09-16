import Foundation

public enum BackendAttestationModeResolver {
    // Protected routes require attestation in every configuration, including Simulator.
    public static func resolve(isAppAttestSupported: Bool) -> BackendAttestationMode {
        isAppAttestSupported ? .appAttest : .unavailable
    }
}
