import Foundation

final class BranchToDeepLinkConversionFactory: BaseInternalLinkFactory {}

private extension BranchToDeepLinkConversionFactory {
    func getAction(from externalParams: ExternalUniversalLinkParams) -> String? {
        externalParams[ExternalUniversalLinkKey.action.rawValue] as? String
    }

    func getActionObject(from externalParams: ExternalUniversalLinkParams) -> String? {
        (externalParams[ExternalUniversalLinkKey.screen.rawValue] as? String) ??
            (externalParams[ExternalUniversalLinkKey.entity.rawValue] as? String)
    }

    func queryItems(externalParams: ExternalUniversalLinkParams) -> [URLQueryItem] {
        let branchSpecials = ["~", "$", "+"]
        let externalKeys = Set(ExternalUniversalLinkKey.allCases.map(\.rawValue))

        return externalParams.compactMap { keyValue in
            guard let keyString = keyValue.key as? String, let valueString = keyValue.value as? String else {
                return nil
            }

            guard
                branchSpecials.allSatisfy({ !keyString.hasPrefix($0) }),
                !externalKeys.contains(keyString) else {
                return nil
            }

            return URLQueryItem(name: keyString, value: valueString)
        }
    }
}

extension BranchToDeepLinkConversionFactory: InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLinkParams) -> URL? {
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.queryItems = queryItems(externalParams: externalParams)

        guard var url = components.url else {
            return nil
        }

        if let action = getAction(from: externalParams) {
            url = url.appendingPathComponent(action)
        }

        if let actionObject = getActionObject(from: externalParams) {
            url = url.appendingPathComponent(actionObject)
        }

        return components.url
    }
}
