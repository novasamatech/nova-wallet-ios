import Foundation

protocol URLHandlingServiceProtocol: AnyObject {
    var validators: [URLActivityValidator] { get }

    func handle(url: URL) -> Bool
}

protocol URLActivityValidator {
    func validate(_ url: URL) -> Bool
}

extension URLHandlingServiceProtocol {
    var validators: [URLActivityValidator] { [] }
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

    @discardableResult
    func handle(url: URL) -> Bool {
        for child in children {
            if child.handle(url: url) {
                return true
            }
        }

        return false
    }
}
