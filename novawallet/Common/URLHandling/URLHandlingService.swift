import Foundation

protocol URLHandlingServiceProtocol: AnyObject {
    func handle(url: URL) -> Bool
}

protocol URLHandlingServiceFacadeProtocol: URLHandlingServiceProtocol {
    func findService<T: URLHandlingServiceProtocol>() -> T?
}

final class URLHandlingService {
    static let shared = URLHandlingService()

    private(set) var children: [URLHandlingServiceProtocol] = []

    func setup(children: [URLHandlingServiceProtocol]) {
        self.children = children
    }
}

extension URLHandlingService: URLHandlingServiceFacadeProtocol {
    func findService<T>() -> T? {
        children.first(where: { $0 is T }) as? T
    }

    func handle(url: URL) -> Bool {
        for child in children {
            if child.handle(url: url) {
                return true
            }
        }

        return false
    }
}
