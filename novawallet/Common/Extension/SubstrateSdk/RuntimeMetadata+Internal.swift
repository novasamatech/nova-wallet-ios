import Foundation
import SubstrateSdk

extension RuntimeMetadataProtocol {
    func getStorageMetadata(for codingPath: StorageCodingPath) -> StorageEntryMetadata? {
        getStorageMetadata(in: codingPath.moduleName, storageName: codingPath.itemName)
    }

    func createEventCodingPath(from moduleIndex: UInt8, eventIndex: UInt32) -> EventCodingPath? {
        guard let moduleName = getModuleName(by: moduleIndex) else {
            return nil
        }

        guard let event = getEventForModuleIndex(moduleIndex, eventIndex: eventIndex) else {
            return nil
        }

        return EventCodingPath(moduleName: moduleName, eventName: event.name)
    }

    func createEventCodingPath(from event: Event) -> EventCodingPath? {
        createEventCodingPath(from: event.moduleIndex, eventIndex: event.eventIndex)
    }

    func eventMatches(_ event: Event, oneOf paths: Set<EventCodingPath>) -> Bool {
        guard let eventCodingPath = createEventCodingPath(from: event) else {
            return false
        }

        return paths.contains(eventCodingPath)
    }

    func eventMatches(_ event: Event, path: EventCodingPath) -> Bool {
        eventMatches(event, oneOf: [path])
    }
}
