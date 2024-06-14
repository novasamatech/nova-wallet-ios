import UIKit

final class NetworkAddNodeInteractor {
    weak var presenter: NetworkAddNodeInteractorOutputProtocol?
}

extension NetworkAddNodeInteractor: NetworkAddNodeInteractorInputProtocol {}
