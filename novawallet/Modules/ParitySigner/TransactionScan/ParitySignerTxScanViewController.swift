import UIKit

final class ParitySignerTxScanViewController: QRScannerViewController {
    override func loadView() {
        view = ParitySignerTxScanViewLayout(settings: settings, frame: .zero)
    }
}

extension ParitySignerTxScanViewController: ParitySignerTxScanViewProtocol {
    func didReceiveExpiration(viewModel: ExpirationTimeViewModel) {
        let rootView = view as? ParitySignerTxScanViewLayout
        rootView?.timerLabel.bindQr(viewModel: viewModel, locale: selectedLocale)
    }
}
