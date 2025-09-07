import UIKit
import Foundation_iOS

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

        rootView.actionView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonConfirm()
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
            rootView.actionView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonConfirm()
        } else {
            rootView.actionView.actionButton.applyDisabledStyle()

            let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.notificationsWalletListSelectionHint(format: 1)

            rootView.actionView.actionButton.imageWithTitleView?.title = title
        }
        rootView.actionView.actionButton.isEnabled = isActionEnabled
    }
}

extension NotificationWalletListViewController: NotificationWalletListViewProtocol {
    func setTitle(_ title: String) {
        rootView.headerView.bind(topValue: title, bottomValue: nil)
    }

    func setAction(enabled: Bool) {
        isActionEnabled = enabled
        updateActionView()
    }
}
