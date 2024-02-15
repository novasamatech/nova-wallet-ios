import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case selectedLocalization
    case biometryEnabled
    case crowdloadChainId
    case stakingNetworkExpansion
    case hidesZeroBalances
    case selectedCurrency
    case governanceChainId
    case governanceType
    case governanceDelegateInfoSeen
    case skippedUpdateVersion
    case skippedAddDelegationTracksHint
    case pinConfirmationEnabled
    case polkadotStakingPromoSeen
    case notificationsEnabled
    case announcements
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

    var pinConfirmationEnabled: Bool? {
        get {
            bool(for: SettingsKey.pinConfirmationEnabled.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.pinConfirmationEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.pinConfirmationEnabled.rawValue)
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

    var skippedAddDelegationTracksHint: Bool {
        get {
            bool(for: SettingsKey.skippedAddDelegationTracksHint.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.skippedAddDelegationTracksHint.rawValue)
        }
    }

    var polkadotStakingPromoSeen: Bool {
        get {
            bool(for: SettingsKey.polkadotStakingPromoSeen.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.polkadotStakingPromoSeen.rawValue)
        }
    }

    var notificationsEnabled: Bool {
        get {
            bool(for: SettingsKey.notificationsEnabled.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.notificationsEnabled.rawValue)
        }
    }

    var announcements: Bool {
        get {
            bool(for: SettingsKey.announcements.rawValue) ?? true
        }

        set {
            set(value: newValue, for: SettingsKey.announcements.rawValue)
        }
    }
}
