import Foundation
import Operation_iOS

/// The remote kill switch, as the package sees it. The host app owns the config format;
/// the package only needs the resolved flag.
///
/// Fail-open is the host's job on the *value* side (a missing analytics block means
/// enabled) and the facade's job on the *error* side: a failed wrapper leaves availability
/// exactly as the attestation ladder set it.
public protocol AnalyticsRemoteSettings {
    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool>
}
