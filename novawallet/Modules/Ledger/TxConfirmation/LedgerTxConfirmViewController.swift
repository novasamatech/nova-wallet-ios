import UIKit
import Foundation_iOS

final class LedgerTxConfirmViewController: LedgerPerformOperationViewController, ImportantViewProtocol {
    var presenter: LedgerTxConfirmPresenterProtocol? { basePresenter as? LedgerTxConfirmPresenterProtocol }

    init(presenter: LedgerTxConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCloseButton()
    }

    private func setupCloseButton() {
        let closeBarItem = UIBarButtonItem(
            image: R.image.iconClose(),
            style: .plain,
            target: self,
            action: #selector(actionClose)
        )

        navigationItem.leftBarButtonItem = closeBarItem
    }

    @objc private func actionClose() {
        presenter?.cancel()
    }
}
