import Foundation
import Keystore_iOS
import NovaCrypto

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
    case notificationsEnabled
    case notificationsSetupSeen
    case lastCloudBackupTimestamp
    case cloudBackupEnabled
    case cloudBackupAutoSyncConfirm
    case cloudBackupPasswordId
    case integrateNetworksBannerSeen
    case assetListGroupStyle
    case assetIconsAppearance
    case novaCardOpenTimestamp
    case closedBanners
    case mythosRestakeEnabled
    case hideUnifiedAddressPopup
    case isAppFirstLaunch
    case multisigNotificationsPromoSeen
    case privacyModeSettings
}

extension SettingsManagerProtocol {
    var isAppFirstLaunch: Bool {
        get {
            bool(for: SettingsKey.isAppFirstLaunch.rawValue) ?? true
        }

        set {
            set(value: newValue, for: SettingsKey.isAppFirstLaunch.rawValue)
        }
    }

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

    var notificationsEnabled: Bool {
        get {
            bool(for: SettingsKey.notificationsEnabled.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.notificationsEnabled.rawValue)
        }
    }

    var notificationsSetupSeen: Bool {
        get {
            bool(for: SettingsKey.notificationsSetupSeen.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.notificationsSetupSeen.rawValue)
        }
    }

    var integrateNetworksBannerSeen: Bool {
        get {
            bool(for: SettingsKey.integrateNetworksBannerSeen.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.integrateNetworksBannerSeen.rawValue)
        }
    }

    var lastCloudBackupTimestampSeen: UInt64? {
        get {
            string(for: SettingsKey.lastCloudBackupTimestamp.rawValue).flatMap { UInt64($0) }
        }

        set {
            if let value = newValue {
                set(value: String(value), for: SettingsKey.lastCloudBackupTimestamp.rawValue)
            } else {
                removeValue(for: SettingsKey.lastCloudBackupTimestamp.rawValue)
            }
        }
    }

    var isCloudBackupEnabled: Bool {
        get {
            bool(for: SettingsKey.cloudBackupEnabled.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.cloudBackupEnabled.rawValue)
        }
    }

    var cloudBackupAutoSyncConfirm: Bool {
        get {
            bool(for: SettingsKey.cloudBackupAutoSyncConfirm.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.cloudBackupAutoSyncConfirm.rawValue)
        }
    }

    var cloudBackupPasswordId: String? {
        get {
            string(for: SettingsKey.cloudBackupPasswordId.rawValue)
        }

        set {
            if let value = newValue {
                set(value: value, for: SettingsKey.cloudBackupPasswordId.rawValue)
            } else {
                removeValue(for: SettingsKey.cloudBackupPasswordId.rawValue)
            }
        }
    }

    var assetListGroupStyle: AssetListGroupsStyle {
        get {
            if let rawValue = string(for: SettingsKey.assetListGroupStyle.rawValue) {
                return AssetListGroupsStyle(rawValue: rawValue) ?? .tokens
            } else {
                return .tokens
            }
        }

        set {
            set(
                value: newValue.rawValue,
                for: SettingsKey.assetListGroupStyle.rawValue
            )
        }
    }

    var assetIconsAppearance: AppearanceIconsOptions {
        get {
            if let rawValue = string(for: SettingsKey.assetIconsAppearance.rawValue) {
                return AppearanceIconsOptions(rawValue: rawValue) ?? .colored
            } else {
                return .colored
            }
        }

        set {
            set(
                value: newValue.rawValue,
                for: SettingsKey.assetIconsAppearance.rawValue
            )
        }
    }

    var novaCardOpenTimestamp: UInt64? {
        get {
            string(for: SettingsKey.novaCardOpenTimestamp.rawValue).flatMap { UInt64($0) }
        }

        set {
            if let value = newValue {
                set(value: String(value), for: SettingsKey.novaCardOpenTimestamp.rawValue)
            } else {
                removeValue(for: SettingsKey.novaCardOpenTimestamp.rawValue)
            }
        }
    }

    var closedBanners: ClosedBanners {
        get {
            value(
                of: ClosedBanners.self,
                for: SettingsKey.closedBanners.rawValue
            ) ?? ClosedBanners()
        }
        set {
            set(
                value: newValue,
                for: SettingsKey.closedBanners.rawValue
            )
        }
    }

    var isMythosRestakeEnabled: Bool {
        get {
            bool(for: SettingsKey.mythosRestakeEnabled.rawValue) ?? true
        }

        set {
            set(value: newValue, for: SettingsKey.mythosRestakeEnabled.rawValue)
        }
    }

    var hideUnifiedAddressPopup: Bool {
        get {
            bool(for: SettingsKey.hideUnifiedAddressPopup.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.hideUnifiedAddressPopup.rawValue)
        }
    }

    var multisigNotificationsPromoSeen: Bool {
        get {
            bool(for: SettingsKey.multisigNotificationsPromoSeen.rawValue) ?? false
        }

        set {
            set(value: newValue, for: SettingsKey.multisigNotificationsPromoSeen.rawValue)
        }
    }

    var privacyModeSettings: PrivacyModeSettings {
        get {
            value(
                of: PrivacyModeSettings.self,
                for: SettingsKey.privacyModeSettings.rawValue
            ) ?? PrivacyModeSettings(
                privacySettingsEnabled: false,
                lastEnabled: false
            )
        }
        set {
            set(
                value: newValue,
                for: SettingsKey.privacyModeSettings.rawValue
            )
        }
    }
}
