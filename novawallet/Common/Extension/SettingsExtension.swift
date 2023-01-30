import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case selectedLocalization
    case biometryEnabled
    case crowdloadChainId
    case stakingAsset
    case stakingNetworkExpansion
    case hidesZeroBalances
    case selectedCurrency
    case governanceChainId
    case governanceType
    case governanceDelegateInfoSeen
    case skippedUpdateVersion
}

extension SettingsManagerProtocol {
    var biometryEnabled: Bool? {
        get {
            bool(for: SettingsKey.biometryEnabled.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.biometryEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.biometryEnabled.rawValue)
            }
        }
    }

    var crowdloanChainId: String? {
        get {
            string(for: SettingsKey.crowdloadChainId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.crowdloadChainId.rawValue)
            } else {
                removeValue(for: SettingsKey.crowdloadChainId.rawValue)
            }
        }
    }

    var governanceChainId: String? {
        get {
            string(for: SettingsKey.governanceChainId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.governanceChainId.rawValue)
            } else {
                removeValue(for: SettingsKey.governanceChainId.rawValue)
            }
        }
    }

    var governanceType: GovernanceType? {
        get {
            if let rawValue = string(for: SettingsKey.governanceType.rawValue) {
                return GovernanceType(rawValue: rawValue)
            } else {
                return nil
            }
        }

        set {
            if let existingValue = newValue {
                set(
                    value: existingValue.rawValue,
                    for: SettingsKey.governanceType.rawValue
                )
            } else {
                removeValue(for: SettingsKey.governanceType.rawValue)
            }
        }
    }

    var stakingAsset: ChainAssetId? {
        get {
            value(of: ChainAssetId.self, for: SettingsKey.stakingAsset.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.stakingAsset.rawValue)
            } else {
                removeValue(for: SettingsKey.stakingAsset.rawValue)
            }
        }
    }

    var stakingNetworkExpansion: Bool {
        get {
            bool(for: SettingsKey.stakingNetworkExpansion.rawValue) ?? true
        }

        set {
            set(value: newValue, for: SettingsKey.stakingNetworkExpansion.rawValue)
        }
    }

    var hidesZeroBalances: Bool {
        get {
            bool(for: SettingsKey.hidesZeroBalances.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.hidesZeroBalances.rawValue)
        }
    }

    var selectedCurrencyId: Int? {
        get {
            integer(for: SettingsKey.selectedCurrency.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.selectedCurrency.rawValue)
            } else {
                removeValue(for: SettingsKey.selectedCurrency.rawValue)
            }
        }
    }

    var governanceDelegateInfoSeen: Bool {
        get {
            bool(for: SettingsKey.governanceDelegateInfoSeen.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.governanceDelegateInfoSeen.rawValue)
    }

    var skippedUpdateVersion: String? {
        get {
            string(for: SettingsKey.skippedUpdateVersion.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.skippedUpdateVersion.rawValue)
            } else {
                removeValue(for: SettingsKey.skippedUpdateVersion.rawValue)
            }
        }
    }
}
