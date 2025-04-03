import Foundation
import Foundation_iOS

enum CloudBackupSettingsIssue {
    case reviewUpdates
    case enterPassword
    case emptyOrBroken
    case icloudError
}

extension CloudBackupSettingsIssue {
    init(backupIssue: CloudBackupSyncResult.Issue) {
        switch backupIssue {
        case .missingPassword, .invalidPassword, .newBackupCreationNeeded:
            self = .enterPassword
        case .remoteDecodingFailed, .remoteEmpty:
            self = .emptyOrBroken
        case .remoteReadingFailed, .internalFailure:
            self = .icloudError
        }
    }
}

protocol CloudBackupSettingsViewModelFactoryProtocol {
    func createViewModel(
        from status: CloudBackupSettingsViewModel.Status,
        lastSync: Date?,
        issue: CloudBackupSettingsIssue?,
        locale: Locale
    ) -> CloudBackupSettingsViewModel
}

extension CloudBackupSettingsViewModelFactoryProtocol {
    private func convert(syncMonitorStatus: CloudBackupSyncMonitorStatus?) -> CloudBackupSettingsViewModel.Status {
        switch syncMonitorStatus {
        case .noFile, .synced, nil:
            return .synced
        case .notDownloaded, .downloading, .uploading:
            return .syncing
        }
    }

    private func createViewModel(
        using result: CloudBackupSyncResult?,
        syncMonitorStatus: CloudBackupSyncMonitorStatus?,
        lastSyncDate: Date?,
        locale: Locale
    ) -> CloudBackupSettingsViewModel {
        switch result {
        case .noUpdates:
            let viewModelStatus = convert(syncMonitorStatus: syncMonitorStatus)

            return createViewModel(
                from: viewModelStatus,
                lastSync: lastSyncDate,
                issue: nil,
                locale: locale
            )
        case .changes:
            return createViewModel(
                from: .unsynced,
                lastSync: lastSyncDate,
                issue: .reviewUpdates,
                locale: locale
            )
        case let .issue(issue):
            return createViewModel(
                from: .unsynced,
                lastSync: lastSyncDate,
                issue: CloudBackupSettingsIssue(backupIssue: issue),
                locale: locale
            )
        case nil:
            return createViewModel(
                from: .syncing,
                lastSync: lastSyncDate,
                issue: nil,
                locale: locale
            )
        }
    }

    func createViewModel(
        with state: CloudBackupSyncState?,
        syncMonitorStatus: CloudBackupSyncMonitorStatus?,
        locale: Locale
    ) -> CloudBackupSettingsViewModel {
        switch state {
        case let .disabled(lastSyncDate):
            return createViewModel(
                from: .disabled,
                lastSync: lastSyncDate,
                issue: nil,
                locale: locale
            )
        case let .unavailable(lastSyncDate):
            return createViewModel(
                from: .unavailable,
                lastSync: lastSyncDate,
                issue: .icloudError,
                locale: locale
            )
        case let .enabled(result, lastSyncDate):
            return createViewModel(
                using: result,
                syncMonitorStatus: syncMonitorStatus,
                lastSyncDate: lastSyncDate,
                locale: locale
            )
        case nil:
            return createViewModel(
                from: .syncing,
                lastSync: nil,
                issue: nil,
                locale: locale
            )
        }
    }
}

final class CloudBackupSettingsViewModelFactory {
    let dateFormatter: LocalizableResource<DateFormatter>

    init(dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.shortDateHoursMinutes) {
        self.dateFormatter = dateFormatter
    }

    private func createTitle(for status: CloudBackupSettingsViewModel.Status, locale: Locale) -> String {
        switch status {
        case .disabled:
            return R.string.localizable.cloudBackupDisabled(preferredLanguages: locale.rLanguages)
        case .syncing:
            return R.string.localizable.cloudBackupSyncing(preferredLanguages: locale.rLanguages)
        case .unsynced, .unavailable:
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
            return R.string.localizable.cloudBackupDisabledDescription(preferredLanguages: locale.rLanguages)
        case .syncing, .unsynced, .synced, .unavailable:
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
        case .emptyOrBroken:
            return R.string.localizable.cloudBackupSettingsEmptyOrBroken(preferredLanguages: locale.rLanguages)
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
