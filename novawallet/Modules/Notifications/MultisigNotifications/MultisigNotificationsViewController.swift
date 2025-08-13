import Foundation
import Foundation_iOS

final class MultisigNotificationsViewController: BaseNotificationSettingsViewController {
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
                R.string.localizable.notificationsManagementMultisigTransactions(
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

    override func setup() {
        setupTableView()
        setupLocalization()
        presenter.setup()
    }

    override func setupTableView() {
        super.setupTableView()

        rootView.tableView.sectionFooterHeight = 0
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard SectionType(section) == .enableSwitch else { return .zero }

        return 26.0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
}

// MARK: - Private

private extension MultisigNotificationsViewController {
    func updateActiveState(
        for sections: [Section],
        active: Bool
    ) {
        sections.enumerated().forEach { sectionIndex, section in
            let updateClosure: (IndexPath) -> Void = { [weak self] indexPath in
                guard let cell = self?.rootView.tableView.cellForRow(
                    at: indexPath
                ) as? SwitchSettingsTableViewCell else {
                    return
                }

                cell.set(active: SectionType(indexPath.section) == .notifications ? active : true)
            }

            guard case let .grouped(rows) = section else {
                updateClosure(IndexPath(row: 0, section: sectionIndex))
                return
            }

            rows.enumerated().forEach {
                updateClosure(IndexPath(row: $0.offset, section: sectionIndex))
            }
        }
    }
}

// MARK: - MultisigNotificationsViewProtocol

extension MultisigNotificationsViewController: MultisigNotificationsViewProtocol {
    func didReceive(viewModel: MultisigNotificationsViewModel) {
        var switchModels = viewModel.switchModels

        let enableSection = Section.common(switchModels.removeFirst())
        let collapsedSection = Section.grouped(switchModels.map { .switchCell($0) })

        let sections = [enableSection, collapsedSection]

        super.set(models: sections)

        DispatchQueue.main.async {
            self.updateActiveState(for: sections, active: viewModel.enabled)
        }
    }
}

// MARK: - Private types

private extension MultisigNotificationsViewController {
    enum SectionType: Int {
        case enableSwitch = 0
        case notifications

        init?(_ index: Int) {
            if let type = SectionType(rawValue: index) {
                self = type
            } else {
                return nil
            }
        }
    }
}
