import Foundation
import Foundation_iOS
import UIKit.UIImage

struct RampAction {
    let type: RampActionType
    let logo: UIImage
    let descriptionText: LocalizableResource<String>
    let url: URL
}

enum RampActionType {
    case offRamp
    case onRamp
}

enum FiatPaymentMethods {
    case visa(UIImage)
    case mastercard(UIImage)
    case applePay(UIImage)
    case sepa(UIImage)
    case others(String)

    var icon: UIImage? {
        switch self {
        case let .visa(value),
             let .mastercard(value),
             let .applePay(value),
             let .sepa(value):
            value
        case .others:
            nil
        }
    }

    var text: String? {
        switch self {
        case let .others(string):
            string
        default:
            nil
        }
    }
}

protocol RampProviderProtocol {
    func with(appName: String) -> Self
    func with(logoUrl: URL) -> Self
    func with(colorCode: String) -> Self
    func with(callbackUrl: URL) -> Self

    func buildRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction]
}

extension RampProviderProtocol {
    func with(appName _: String) -> Self {
        self
    }

    func with(logoUrl _: URL) -> Self {
        self
    }

    func with(colorCode _: String) -> Self {
        self
    }

    func with(callbackUrl _: URL) -> Self {
        self
    }
}
