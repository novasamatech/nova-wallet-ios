import Foundation
import SoraFoundation

enum CloudBackupSettingsIssue {
    case reviewUpdates
    case enterPassword
    case icloudError
}

protocol CloudBackupSettingsViewModelFactoryProtocol {
    func createViewModel(
        from status: CloudBackupSettingsViewModel.Status,
        lastSync: Date?,
        issue: CloudBackupSettingsIssue?,
        locale: Locale
    ) -> CloudBackupSettingsViewModel
}

final class CloudBackupSettingsViewModelFactory {
    let dateFormatter: LocalizableResource<DateFormatter>

    init(dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.shortDateAndTime) {
        self.dateFormatter = dateFormatter
    }

    private func createTitle(for status: CloudBackupSettingsViewModel.Status, locale: Locale) -> String {
        switch status {
        case .disabled:
            return R.string.localizable.cloudBackupDisabled(preferredLanguages: locale.rLanguages)
        case .syncing:
            return R.string.localizable.cloudBackupSyncing(preferredLanguages: locale.rLanguages)
        case .unsynced:
            return R.string.localizable.cloudBackupUnsynced(preferredLanguages: locale.rLanguages)
        case .synced:
            return R.string.localizable.cloudBackupSynced(preferredLanguages: locale.rLanguages)
        }
    }

    private func createSubtitle(
        for status: CloudBackupSettingsViewModel.Status,
        lastSync: Date?,
        locale: Locale
    ) -> String? {
        switch status {
        case .disabled:
            return R.string.localizable.cloudBackupDisabled(preferredLanguages: locale.rLanguages)
        case .syncing, .unsynced, .synced:
            if let lastSync {
                let formattedDate = dateFormatter.value(for: locale).string(from: lastSync)
                return R.string.localizable.cloudBackupLastSyncedFormat(
                    formattedDate,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return nil
            }
        }
    }

    private func createIssue(from type: CloudBackupSettingsIssue, locale: Locale) -> String {
        switch type {
        case .reviewUpdates:
            return R.string.localizable.cloudBackupReviewBackupUpdates(preferredLanguages: locale.rLanguages)
        case .enterPassword:
            return R.string.localizable.cloudBackupEnterPasswordIssue(preferredLanguages: locale.rLanguages)
        case .icloudError:
            return R.string.localizable.cloudBackupReviewIcloudIssue(preferredLanguages: locale.rLanguages)
        }
    }
}

extension CloudBackupSettingsViewModelFactory: CloudBackupSettingsViewModelFactoryProtocol {
    func createViewModel(
        from status: CloudBackupSettingsViewModel.Status,
        lastSync: Date?,
        issue: CloudBackupSettingsIssue?,
        locale: Locale
    ) -> CloudBackupSettingsViewModel {
        .init(
            status: status,
            title: createTitle(for: status, locale: locale),
            lastSynced: createSubtitle(for: status, lastSync: lastSync, locale: locale),
            issue: issue.map { createIssue(from: $0, locale: locale) }
        )
    }
}
