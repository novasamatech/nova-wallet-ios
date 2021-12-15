import UIKit

final class DAppBrowserInteractor {
    weak var presenter: DAppBrowserInteractorOutputProtocol!
}

extension DAppBrowserInteractor: DAppBrowserInteractorInputProtocol {}
