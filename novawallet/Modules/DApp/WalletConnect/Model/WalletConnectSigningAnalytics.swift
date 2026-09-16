import Foundation
import WalletConnectSign
import NovaAnalytics

struct WalletConnectSigningAnalytics: AnalyticsTracking {
    func trackSignFailed(request: Request, reason: SignFailureReason) {
        guard
            let methodValue = AnalyticsContentValue.signingMethod(request.method),
            let chainValue = AnalyticsContentValue.caip2Chain(request.chainId.absoluteString) else {
            return
        }

        trackAnalytics(
            .signFailed(
                source: .walletConnect,
                method: methodValue,
                chain: chainValue,
                reason: reason
            )
        )
    }
}
