import Foundation
import SoraFoundation

final class ParitySignerTxQrWireframe: ParitySignerTxQrWireframeProtocol {
    func close(view: ParitySignerTxQrViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func proceed(from _: ParitySignerTxQrViewProtocol?, timer _: CountdownTimerProtocol) {}

    func showTroubleshouting(from _: ParitySignerTxQrViewProtocol?) {}
}
