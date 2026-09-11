import Foundation
import CoreData

extension NSSortDescriptor {
    static var analyticsEventsBySequence: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDAnalyticsEvent.sequence), ascending: true)
    }
}
