import Foundation
import CoreData

extension NSSortDescriptor {
    /// FIFO order for the pending-event queue.
    static var analyticsEventsBySequence: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDAnalyticsEvent.sequence), ascending: true)
    }
}
