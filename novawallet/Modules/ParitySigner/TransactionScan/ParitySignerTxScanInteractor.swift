import UIKit

final class ParitySignerTxScanInteractor {
    weak var presenter: ParitySignerTxScanInteractorOutputProtocol!
}

extension ParitySignerTxScanInteractor: ParitySignerTxScanInteractorInputProtocol {}
