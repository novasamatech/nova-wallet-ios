import UIKit

final class NetworkDetailsInteractor {
    weak var presenter: NetworkDetailsInteractorOutputProtocol!
}

extension NetworkDetailsInteractor: NetworkDetailsInteractorInputProtocol {}
