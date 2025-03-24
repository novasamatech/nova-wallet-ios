import Foundation
import SoraFoundation
import UIKit.UIImage

struct RampAction {
    let logo: UIImage
    let descriptionText: LocalizableResource<String>
    let fiatPaymentMethods: [FiatPaymentMethods]
    let url: URL
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

    func buildOffRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction]

    func buildOnRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction]
}

extension RampProviderProtocol {
    var defaultPaymentMethods: [FiatPaymentMethods] {
        [
            .visa(R.image.visaLogo()!),
            .mastercard(R.image.mastercardLogo()!),
            .applePay(R.image.applePayLogo()!),
            .sepa(R.image.sepaLogo()!)
        ]
    }

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
