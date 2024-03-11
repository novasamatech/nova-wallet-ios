import UIKit
import SoraFoundation

class ChainNotificationSettingsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChainNotificationSettingsViewLayout

    private let presenter: ChainNotificationSettingsPresenterProtocol
    private var models: [Section] = []

    init(
        presenter: ChainNotificationSettingsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChainNotificationSettingsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupTableView()
        setupLocalization()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SwitchSettingsTableViewCell.self)
        rootView.tableView.registerClassForCell(SettingsSubtitleTableViewCell.self)
    }

    private func setupLocalization() {
        let rightBarButtonItemTitle = R.string.localizable.commonClear(
            preferredLanguages: selectedLocale.rLanguages)
        navigationItem.title = R.string.localizable.tabbarGovernanceTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        navigationItem.rightBarButtonItem?.title = rightBarButtonItemTitle
    }

    private func setupNavigationItem() {
        let title = R.string.localizable.commonClear(preferredLanguages: selectedLocale.rLanguages)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: title,
            style: .plain,
            target: self,
            action: #selector(clearAction)
        )
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.tintColor = R.color.colorButtonTextAccent()
    }

    @objc private func clearAction() {
        presenter.clear()
    }

    private func switchCell(
        _ tableView: UITableView,
        indexPath: IndexPath,
        model: SwitchTitleIconViewModel
    ) -> SwitchSettingsTableViewCell {
        let cell: SwitchSettingsTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.bind(icon: model.icon, title: model.title, isOn: model.isOn)
        cell.iconImageView.isHidden = model.icon == nil
        cell.delegate = self
        cell.roundView.fillColor = R.color.colorBlockBackgroundOpaque()!
        return cell
    }

    private func accessoryCell(
        _ tableView: UITableView,
        indexPath: IndexPath,
        model: AccessoryTitleIconViewModel
    ) -> SettingsSubtitleTableViewCell {
        let cell: SettingsSubtitleTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.bind(title: model.title, accessoryViewModel: model.accessory)
        cell.iconImageView.isHidden = true
        cell.roundView.fillColor = R.color.colorBlockBackgroundOpaque()!
        return cell
    }

    private func action(section: Int, row: Int) {
        let model = models[section]
        switch model {
        case let .collapsable(cells):
            switch cells[row] {
            case let .accessoryCell(accessory):
                accessory.action()
            case let .switchCell(switchCell):
                models[section] = model.togglingSwitch(at: row)
                models[section].isOn(at: row).map { switchCell.action($0) }

                if row == 0 {
                    rootView.tableView.reloadSections([section], with: .automatic)
                    return
                }
            }
        case let .common(cell):
            models[section] = model.togglingSwitch(at: row)
            models[section].isOn(at: row).map { cell.action($0) }
        }

        rootView.tableView.reloadRows(at: [.init(row: row, section: section)], with: .automatic)
    }
}

extension ChainNotificationSettingsViewController {
    func set(isClearActionAvailabe: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = isClearActionAvailabe
    }

    func set(models: [Section]) {
        self.models = models
        rootView.tableView.reloadData()
    }

    func update(model: Section, at index: Int) {
        models[index] = model
        rootView.tableView.reloadSections([index], with: .automatic)
    }
}

extension ChainNotificationSettingsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        models.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch models[section] {
        case let .collapsable(cells):
            guard !cells.isEmpty, case let .switchCell(model) = cells[0] else {
                return 0
            }
            return model.isOn ? cells.count : 1
        case .common:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = models[indexPath.section]

        switch section {
        case let .common(cell):
            let cell = switchCell(tableView, indexPath: indexPath, model: cell)
            cell.apply(position: .single)
            return cell
        case let .collapsable(cells):
            switch cells[indexPath.row] {
            case let .accessoryCell(accessoryModel):
                let cell = accessoryCell(tableView, indexPath: indexPath, model: accessoryModel)
                cell.apply(position: .init(row: indexPath.row, count: cells.count))
                return cell
            case let .switchCell(switchModel):
                let visibleCellsCount = cells[safe: 0]?.isOn == true ? cells.count : 1
                let cell = switchCell(tableView, indexPath: indexPath, model: switchModel)
                cell.apply(position: .init(row: indexPath.row, count: visibleCellsCount))
                return cell
            }
        }
    }
}

extension ChainNotificationSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        action(section: indexPath.section, row: indexPath.row)
    }
}

extension ChainNotificationSettingsViewController: SwitchSettingsTableViewCellDelegate {
    func didToggle(cell: SwitchSettingsTableViewCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        action(section: indexPath.section, row: indexPath.row)
    }
}

extension ChainNotificationSettingsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension ChainNotificationSettingsViewController {
    enum Row {
        case switchCell(SwitchTitleIconViewModel)
        case accessoryCell(AccessoryTitleIconViewModel)

        var isOn: Bool? {
            switch self {
            case let .switchCell(model):
                return model.isOn
            case .accessoryCell:
                return nil
            }
        }
    }

    enum Section {
        case collapsable([Row])
        case common(SwitchTitleIconViewModel)

        func togglingSwitch(at index: Int) -> Section {
            switch self {
            case var .collapsable(cells):
                guard case var .switchCell(model) = cells[index] else {
                    return self
                }
                model.isOn.toggle()
                cells[index] = .switchCell(model)
                return .collapsable(cells)
            case var .common(cell):
                cell.isOn.toggle()
                return .common(cell)
            }
        }

        func isOn(at index: Int) -> Bool? {
            switch self {
            case let .collapsable(cells):
                return cells[index].isOn
            case let .common(cell):
                return cell.isOn
            }
        }
    }
}
