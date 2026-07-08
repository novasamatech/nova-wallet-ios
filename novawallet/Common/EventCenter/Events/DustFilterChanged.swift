import Foundation

struct DustFilterChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processDustFilterChanged(event: self)
    }
}
