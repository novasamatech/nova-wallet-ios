import UIKit
import SoraFoundation

final class NotificationWalletListViewController: WalletsListViewController<
    NotificationWalletListViewLayout,
    WalletCheckboxTableViewCell
> {
    typealias RootViewType = NotificationWalletListViewLayout

    var presenter: NotificationWalletListPresenterProtocol? {
        basePresenter as? NotificationWalletListPresenterProtocol
    }

    private var isActionEnabled: Bool = false

    init(
        presenter: NotificationWalletListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
    }

    override func loadView() {
        view = NotificationWalletListViewLayout()
    }

    override func setupLocalization() {
        super.setupLocalization()

        let title = R.string.localizable.notificationsWalletListTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.headerView.bind(topValue: title, bottomValue: nil)
        rootView.actionView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: selectedLocale.rLanguages
        )
        updateActionView()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        presenter?.selectItem(at: indexPath.row, section: indexPath.section)
    }

    private func setupHandlers() {
        rootView.actionView.actionButton.addTarget(
            self,
            action: #selector(applyAction),
            for: .touchUpInside
        )
    }

    @objc private func applyAction() {
        presenter?.confirm()
    }

    private func updateActionView() {
        if isActionEnabled {
            rootView.actionView.actionButton.applyDefaultStyle()
            rootView.actionView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            rootView.actionView.actionButton.applyDisabledStyle()
            rootView.actionView.actionButton.imageWithTitleView?.title = R.string.localizable.notificationsWalletListSelectionHint(
                preferredLanguages: selectedLocale.rLanguages
            )
        }
        rootView.actionView.actionButton.isEnabled = isActionEnabled
    }
}

extension NotificationWalletListViewController: NotificationWalletListViewProtocol {
    func setAction(enabled: Bool) {
        isActionEnabled = enabled
        updateActionView()
    }
}
