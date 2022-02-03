import UIKit

final class AssetsManageInteractor {
    weak var presenter: AssetsManageInteractorOutputProtocol!
}

extension AssetsManageInteractor: AssetsManageInteractorInputProtocol {}