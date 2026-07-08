import Foundation

struct UserAddedTokensChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processUserAddedTokensChanged(event: self)
    }
}
