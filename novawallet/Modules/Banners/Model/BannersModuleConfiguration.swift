import Foundation

enum Banners {
    struct ModuleConfiguration {
        let closeActionAvailable: Bool
        let domain: Domain
    }

    enum Domain: String, Codable {
        case dApps = "dapps"
        case assets
        case ahmKusama = "ahm_kusama"
        case ahmPolkadot = "ahm_polkadot"
    }
}

extension Banners.ModuleConfiguration {
    static let dApps: Banners.ModuleConfiguration = .init(
        closeActionAvailable: false,
        domain: .dApps
    )
    static let assets: Banners.ModuleConfiguration = .init(
        closeActionAvailable: true,
        domain: .assets
    )
}
