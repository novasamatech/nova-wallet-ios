import UIKit

final class YourWalletsInteractor {
    weak var presenter: YourWalletsInteractorOutputProtocol!
}

extension YourWalletsInteractor: YourWalletsInteractorInputProtocol {}
