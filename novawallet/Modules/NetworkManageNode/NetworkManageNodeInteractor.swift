import UIKit

final class NetworkManageNodeInteractor {
    weak var presenter: NetworkManageNodeInteractorOutputProtocol?
}

extension NetworkManageNodeInteractor: NetworkManageNodeInteractorInputProtocol {}