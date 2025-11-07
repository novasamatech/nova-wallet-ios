import Foundation

typealias ExternalUniversalLinkParams = [AnyHashable: Any]

enum ExternalUniversalLinkKey: String, CaseIterable {
    case action
    case screen
    case entity
    case data
}
