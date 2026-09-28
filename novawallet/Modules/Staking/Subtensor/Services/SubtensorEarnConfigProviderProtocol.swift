import Foundation
import Operation_iOS

protocol SubtensorEarnConfigProviderProtocol: AnyObject {
    func createConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig>

    func createBackgroundConfigWrapper() -> CompoundOperationWrapper<SubtensorEarnConfig>
}

struct SubtensorEarnConfigRemoteEntry: Codable, Equatable {
    let entry: SubtensorEarnConfig.EntryFlags?
}

protocol SubtensorEarnConfigEntryStoring: AnyObject {
    func loadRemoteEntry() -> SubtensorEarnConfigRemoteEntry?

    func saveRemoteEntry(_ entry: SubtensorEarnConfigRemoteEntry?)
}
