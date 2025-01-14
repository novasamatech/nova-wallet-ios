import Foundation
import Operation_iOS

final class WalletBrowserStateCleaner {
    private let browserTabManager: DAppBrowserTabManagerProtocol
    private let webViewPoolEraser: WebViewPoolEraserProtocol

    init(
        browserTabManager: DAppBrowserTabManagerProtocol,
        webViewPoolEraser: WebViewPoolEraserProtocol
    ) {
        self.browserTabManager = browserTabManager
        self.webViewPoolEraser = webViewPoolEraser
    }
}

// MARK: Private

private extension WalletBrowserStateCleaner {}

// MARK: WalletDeleteStorageCleaning

extension WalletBrowserStateCleaner: WalletDeleteStorageCleaning {
    func cleanStorage(for _: MetaAccountModel) -> CompoundOperationWrapper<Void> {
        .createWithResult(())
    }
}
