import UIKit

enum ParitySignerType {
    case legacy
    case vault

    func getName(for locale: Locale) -> String {
        switch self {
        case .legacy:
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonParitySigner()
        case .vault:
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonPolkadotVault()
        }
    }

    var icon: UIImage? {
        switch self {
        case .legacy:
            return R.image.iconParitySigner()
        case .vault:
            return R.image.iconPolkadotVault()
        }
    }

    var iconForAction: UIImage? {
        switch self {
        case .legacy:
            return R.image.iconParitySignerAction()
        case .vault:
            return R.image.iconPolkadotVaultAction()
        }
    }

    var iconForHeader: UIImage? {
        switch self {
        case .legacy:
            return R.image.iconParitySignerHeader()
        case .vault:
            return R.image.iconPolkadotVaultHeader()
        }
    }

    var iconForSheet: UIImage? {
        switch self {
        case .legacy:
            return R.image.iconPolkadotVaultInSheet()
        case .vault:
            return R.image.iconPolkadotVaultInSheet()
        }
    }

    func getTroubleshootingUrl(for applicationConfig: ApplicationConfigProtocol) -> URL {
        switch self {
        case .legacy:
            return applicationConfig.paritySignerTroubleshoutingURL
        case .vault:
            return applicationConfig.polkadotVaultTroubleshoutingURL
        }
    }
}
