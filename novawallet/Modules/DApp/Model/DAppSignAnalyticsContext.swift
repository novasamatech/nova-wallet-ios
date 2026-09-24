import Foundation
import NovaAnalytics

struct DAppSignAnalyticsContext {
    let source: SignSource
    let method: AnalyticsContentValue
    let chain: AnalyticsContentValue

    init?(request: DAppOperationRequest, type: DAppSigningType) {
        guard
            let method = AnalyticsContentValue.signingMethod(type.analyticsSigningMethod),
            let chain = type.analyticsChain else {
            return nil
        }

        source = request.transportName == DAppTransports.walletConnect ? .walletConnect : .dappBrowser
        self.method = method
        self.chain = chain
    }
}

// MARK: Private

private extension DAppSigningType {
    var analyticsSigningMethod: String {
        switch self {
        case .extrinsic:
            return "polkadot_signPayload"
        case .bytes:
            return "polkadot_signRaw"
        case .ethereumSendTransaction:
            return "eth_sendTransaction"
        case .ethereumSignTransaction:
            return "eth_signTransaction"
        case .ethereumBytes:
            return "personal_sign"
        }
    }

    var analyticsChain: AnalyticsContentValue? {
        switch self {
        case let .extrinsic(chain), let .bytes(chain):
            return chain.analyticsNetworkName
        case let .ethereumSendTransaction(chain),
             let .ethereumSignTransaction(chain),
             let .ethereumBytes(chain):
            return AnalyticsContentValue.networkName(chain.networkName)
        }
    }
}
