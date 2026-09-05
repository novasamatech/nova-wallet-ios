import Foundation

struct GlobalConfig: Decodable {
    let multiStakingApiUrl: URL
    let multisigsApiUrl: URL
    let proxyApiUrl: URL
    /// Optional so a `config.json` shipped without this section still decodes.
    let analytics: AnalyticsRemoteConfig?
}

/// The remote kill switch. `enabled == false` means exactly what an
/// unattestable device means, not a second upload-only "off".
struct AnalyticsRemoteConfig: Decodable {
    let enabled: Bool
    let minVersion: String?
}
