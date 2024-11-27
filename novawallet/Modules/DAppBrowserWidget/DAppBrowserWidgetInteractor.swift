import UIKit

final class DAppBrowserWidgetInteractor {
    weak var presenter: DAppBrowserWidgetInteractorOutputProtocol?
}

extension DAppBrowserWidgetInteractor: DAppBrowserWidgetInteractorInputProtocol {}