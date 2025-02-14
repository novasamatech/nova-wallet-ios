import Foundation

enum Banners {
    struct ModuleConfiguration {
        let closeActionAvailable: Bool
        let domain: Domain
    }

    enum Domain: String {
        case dApps = "dapps"
        case assets
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
