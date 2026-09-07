import Foundation
import CoreData

@objc(CDAnalyticsEvent)
final class CDAnalyticsEvent: NSManagedObject {
    @NSManaged var consentEpoch: Int64
    @NSManaged var identifier: String?
    @NSManaged var name: String?
    @NSManaged var payload: Data?
    @NSManaged var sequence: Int64
    @NSManaged var timestamp: Date?
}
