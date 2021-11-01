import Foundation

@available(*, deprecated, renamed: "SelectedMetaAccountChanged")
struct SelectedAccountChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedAccountChanged(event: self)
    }
}

struct SelectedMetaAccountChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedMetaAccountChanged(event: self)
    }
}
