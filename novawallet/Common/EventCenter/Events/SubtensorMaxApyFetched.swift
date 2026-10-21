import Foundation

struct SubtensorMaxApyFetched: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSubtensorMaxApyFetched(event: self)
    }
}
