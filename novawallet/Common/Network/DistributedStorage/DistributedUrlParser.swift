import Foundation

enum DistributedStorageScheme: String {
    case ipfs
}

enum DistributedStorage {
    case ipfs(hash: String)
}

protocol DistributedUrlParserProtocol {
    func parse(url: String) -> DistributedStorage?
}

extension DistributedUrlParserProtocol {
    func isDistributedUrl(_ url: String) -> Bool {
        switch parse(url: url) {
        case .ipfs:
            return true
        case .none:
            return false
        }
    }
}

final class DistributedUrlParser: DistributedUrlParserProtocol {
    func parse(url: String) -> DistributedStorage? {
        guard
            let urlComponents = URLComponents(string: url),
            let scheme = urlComponents.scheme else {
            return nil
        }

        switch DistributedStorageScheme(rawValue: scheme) {
        case .ipfs:
            return .ipfs(hash: urlComponents.path)
        case .none:
            return nil
        }
    }
}
