import UIKit

class SettingsTableDataSource<TRow, TSection>: NSObject, UITableViewDataSource {
    var sections: [(TSection, [CommonSettingsCellViewModel<TRow>])] = []
    weak var switchDelegate: SwitchSettingsTableViewCellDelegate?

    func registerCells(for tableView: UITableView) {
        tableView.registerClassForCell(SettingsTableViewCell.self)
        tableView.registerClassForCell(SwitchSettingsTableViewCell.self)
        tableView.registerClassForCell(SettingsSubtitleTableViewCell.self)
        tableView.registerClassForCell(SettingsBoxTableViewCell.self)
    }

    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].1.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModels = sections[indexPath.section].1
        let cellViewModel = viewModels[indexPath.row]

        let cell: UITableViewCell & TableViewCellPositioning

        switch cellViewModel.accessory {
        case let .title(viewModel):
            let subtitleCell = tableView.dequeueReusableCellWithType(SettingsSubtitleTableViewCell.self)!
            subtitleCell.bind(titleViewModel: cellViewModel.title, accessoryViewModel: viewModel)
            subtitleCell.hideImageViewIfNeeded(titleViewModel: cellViewModel.title)
            cell = subtitleCell
        case let .box(viewModel):
            let boxCell = tableView.dequeueReusableCellWithType(SettingsBoxTableViewCell.self)!
            boxCell.bind(titleViewModel: cellViewModel.title, accessoryViewModel: viewModel)
            cell = boxCell
        case let .switchControl(isOn):
            let switchCell = tableView.dequeueReusableCellWithType(SwitchSettingsTableViewCell.self)!
            switchCell.bind(titleViewModel: cellViewModel.title, isOn: isOn)
            switchCell.hideImageViewIfNeeded(titleViewModel: cellViewModel.title)
            switchCell.delegate = switchDelegate
            cell = switchCell
        case .none:
            let titleCell = tableView.dequeueReusableCellWithType(SettingsTableViewCell.self)!
            titleCell.bind(titleViewModel: cellViewModel.title)
            titleCell.hideImageViewIfNeeded(titleViewModel: cellViewModel.title)
            cell = titleCell
        }

        cell.apply(position: .init(row: indexPath.row, count: viewModels.count))

        return cell
    }
}

struct CommonSettingsCellViewModel<TRow> {
    enum Accessory {
        case title(String)
        case box(TitleIconViewModel)
        case switchControl(isOn: Bool)
        case none

        init(optTitle: String?) {
            if let title = optTitle {
                self = .title(title)
            } else {
                self = .none
            }
        }

        init(optTitle: String?, icon: UIImage?) {
            if let title = optTitle {
                self = .box(.init(title: title, icon: icon))
            } else {
                self = .none
            }
        }
    }

    let row: TRow
    let title: TitleIconViewModel
    let accessory: Accessory
}
