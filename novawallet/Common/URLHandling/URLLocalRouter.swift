import Foundation
import UIKit

protocol URLLocalRouting {
    func canOpenLocalUrl(_ url: URL) -> Bool
    func openLocalUrl(_ url: URL)
}

final class URLLocalRouter {
    let supportedSchemes: Set<String>

    init(supportedSchemes: Set<String>) {
        self.supportedSchemes = supportedSchemes
    }
}

extension URLLocalRouter: URLLocalRouting {
    func canOpenLocalUrl(_ url: URL) -> Bool {
        guard let scheme = url.scheme else {
            return false
        }

        return supportedSchemes.contains(scheme)
    }

    func openLocalUrl(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

extension URLLocalRouter {
    static func createWithDeeplinks() -> URLLocalRouter {
        .init(supportedSchemes: ["novawallet", "wc", "rainbow"])
    }
}
