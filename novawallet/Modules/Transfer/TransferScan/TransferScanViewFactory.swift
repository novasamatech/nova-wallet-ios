import Foundation
import SoraFoundation

struct TransferScanViewFactory {
    static func createView(
        for delegate: TransferScanDelegate
    ) -> QRScannerViewProtocol? {
        // TODO: get rid of format
        let matcher = AddressQRMatcher(chainFormat: .substrate(42))
        let qrService = QRCaptureService(delegate: nil)

        let wireframe = QRScannerWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = TransferScanPresenter(
            matcher: matcher,
            wireframe: wireframe,
            delegate: delegate,
            qrScanService: qrService,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = QRScannerViewController(
            title: LocalizableResource { locale in
                R.string.localizable.recepientScanTitle(preferredLanguages: locale.rLanguages)
            },
            message: LocalizableResource { locale in
                R.string.localizable.recepientScanMessage(preferredLanguages: locale.rLanguages)
            },
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
