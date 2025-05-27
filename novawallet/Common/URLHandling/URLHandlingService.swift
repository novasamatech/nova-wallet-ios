import Foundation

protocol URLHandlingServiceProtocol: AnyObject {
    func handle(url: URL) -> Bool
}

protocol URLActivityValidator {
    func validate(_ url: URL) -> Bool
}

protocol URLServiceHandlingFinding: URLHandlingServiceProtocol {
    func findService<T>() -> T?
}

final class URLHandlingService {
    let children: [URLHandlingServiceProtocol]

    init(children: [URLHandlingServiceProtocol]) {
        self.children = children
    }
}

extension URLHandlingService: URLServiceHandlingFinding {
    @discardableResult
    func handle(url: URL) -> Bool {
        for child in children {
            if child.handle(url: url) {
                return true
            }
        }

        return false
    }

    func findService<T>() -> T? {
        children.first(where: { $0 is T }) as? T
    }
}
