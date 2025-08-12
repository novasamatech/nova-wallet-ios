import Foundation
import Foundation_iOS

final class MultisigNotificationsViewController: ChainNotificationSettingsViewController {
    let presenter: MultisigNotificationsPresenterProtocol

    init(
        presenter: MultisigNotificationsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(
            presenter: presenter,
            localizationManager: localizationManager,
            navigationItemTitle: .init {
                R.string.localizable.notificationsManagementStakingRewards(
                    preferredLanguages: $0.rLanguages
                )
            }
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.proceed()
    }
}

extension MultisigNotificationsViewController: MultisigNotificationsViewProtocol {
    func didReceive(viewModel: MultisigNotificationsViewModel) {
        let sections = viewModel.switchModels.map { Section.common($0) }

        super.set(models: sections)
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        .zero
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        .zero
    }
}
