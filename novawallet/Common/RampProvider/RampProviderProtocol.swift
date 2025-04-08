import Foundation
import Foundation_iOS
import UIKit.UIImage

struct RampAction {
    let type: RampActionType
    let logo: UIImage
    let descriptionText: LocalizableResource<String>
    let url: URL
    let displayURLString: String
    let paymentMethods: [FiatPaymentMethods]
}

enum RampActionType {
    case offRamp
    case onRamp
}

enum FiatPaymentMethods {
    case visa
    case mastercard
    case applePay
    case sepa
    case others(count: Int)
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

    func buildRampHooks(
        for action: RampAction,
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate & OnRampHookDelegate
    ) -> [RampHook]
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

protocol BaseURLStringProvider {
    var baseUrlString: String { get }
}

protocol OffRampHookFactoryProvider {
    var offRampHookFactory: OffRampHookFactoryProtocol { get }
}

protocol OnRampHookFactoryProvider {
    var onRampHookFactory: OnRampHookFactoryProtocol { get }
}

extension RampProviderProtocol where Self: BaseURLStringProvider,
    Self: OffRampHookFactoryProvider,
    Self: OnRampHookFactoryProvider {
    func buildRampHooks(
        for action: RampAction,
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate & OnRampHookDelegate
    ) -> [RampHook] {
        guard
            let host = action.url.host(),
            baseUrlString.contains(substring: host)
        else { return [] }

        return switch action.type {
        case .onRamp:
            onRampHookFactory.createHooks(for: delegate)
        case .offRamp:
            offRampHookFactory.createHooks(
                using: params,
                for: delegate
            )
        }
    }
}
