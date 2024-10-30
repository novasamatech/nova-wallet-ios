import Foundation
import CoreData

class AssetIconURLToStringMigrationPolicy: NSEntityMigrationPolicy {
    @objc func iconURLToString(_: URL?) -> String? {
        nil
    }
}
