import Foundation

typealias BranchLinkParams = [AnyHashable: Any]

protocol BranchDeepLinkFactoryProtocol {
    func createDeepLink(from branchParams: BranchLinkParams) -> URL?
}

final class BranchDeepLinkFactory {}

extension BranchDeepLinkFactory: BranchDeepLinkFactoryProtocol {
    func createDeepLink(from _: BranchLinkParams) -> URL? {
        nil
    }
}
