import Foundation
import CoreData

/// Written by hand because SwiftPM does not run Xcode's CoreData code generator — it only
/// compiles the model with `momc`. The model therefore declares
/// `codeGenerationType="none"`, and this must stay in step with it.
@objc(CDAnalyticsEvent)
final class CDAnalyticsEvent: NSManagedObject {
    @NSManaged var identifier: String?
    @NSManaged var name: String?
    @NSManaged var payload: Data?
    @NSManaged var sequence: Int64
    @NSManaged var timestamp: Date?
}
