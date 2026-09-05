import Foundation

public enum BackendAttestationModeResolver {
    public static func resolve(isReleaseBuild: Bool, isAppAttestSupported: Bool) -> BackendAttestationMode {
        if isAppAttestSupported {
            return .appAttest
        }

        return isReleaseBuild ? .unavailable : .none
    }
}
