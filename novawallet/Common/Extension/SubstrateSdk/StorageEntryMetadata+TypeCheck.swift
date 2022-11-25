import Foundation
import SubstrateSdk

extension RuntimeMetadataProtocol {
    func isMapStorageKeyOfType(_ storagePath: StorageCodingPath, closure: (String) -> Bool) -> Bool {
        guard let storage = getStorageMetadata(
            in: storagePath.moduleName,
            storageName: storagePath.itemName
        ) else {
            return false
        }

        return storage.isMapKeyOfType(closure)
    }
}

extension StorageEntryMetadata {
    func isMapKeyOfType(_ closure: (String) -> Bool) -> Bool {
        switch type {
        case let .map(entry):
            return closure(entry.key)
        default:
            return false
        }
    }
}
