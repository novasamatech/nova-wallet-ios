import Foundation
import Keystore_iOS

final class SubtensorEarnConfigEntryStore {
    private let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

extension SubtensorEarnConfigEntryStore: SubtensorEarnConfigEntryStoring {
    func loadRemoteEntry() -> SubtensorEarnConfigRemoteEntry? {
        settingsManager.value(of: SubtensorEarnConfigRemoteEntry.self, for: Key.remoteEntry)
    }

    func saveRemoteEntry(_ entry: SubtensorEarnConfigRemoteEntry?) {
        if let entry {
            settingsManager.set(value: entry, for: Key.remoteEntry)
        } else {
            settingsManager.removeValue(for: Key.remoteEntry)
        }
    }
}

private extension SubtensorEarnConfigEntryStore {
    enum Key {
        static let remoteEntry = "subtensorEarnConfigRemoteEntry"
    }
}
