import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworksInteractor {
    weak var presenter: NetworksInteractorOutputProtocol!
}

extension NetworksInteractor: NetworksInteractorInputProtocol {
    func setup() {}
}
