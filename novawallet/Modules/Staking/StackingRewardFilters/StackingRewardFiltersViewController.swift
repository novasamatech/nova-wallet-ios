import UIKit
import SoraFoundation

final class StackingRewardFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = StackingRewardFiltersViewLayout

    let presenter: StackingRewardFiltersPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private lazy var dataSource = createDataSource()
    var viewModel: StackingRewardFiltersViewModel?

    init(
        presenter: StackingRewardFiltersPresenterProtocol,
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
        view = StackingRewardFiltersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupSaveButton()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.registerHeaderFooterView(withClass: StackingRewardActionControl.self)
        rootView.tableView.registerClassForCell(SelectableFilterCell.self)
        rootView.tableView.registerClassForCell(TitleSubtitleSwitchTableViewCell.self)
        rootView.tableView.registerClassForCell(StackingRewardDateCell.self)
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
    }

    private func setupSaveButton() {
        let saveButton = UIBarButtonItem(
            title: R.string.localizable.commonSave(preferredLanguages: selectedLocale.rLanguages),
            style: .plain,
            target: self,
            action: #selector(saveButtonAction)
        )

        saveButton.setupDefaultTitleStyle(with: .regularBody)
        navigationItem.rightBarButtonItem = saveButton
    }

    @objc private func saveButtonAction() {
        presenter.save()
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            tableView: rootView.tableView,
            cellProvider: { tableView, indexPath, model ->
                UITableViewCell? in
                switch model {
                case let .selectable(model):
                    let cell: SelectableFilterCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.bind(viewModel: .init(underlyingViewModel: model.title, selectable: model.selected))
                    return cell
                case let .togglable(title, isEnabled):
                    let cell: TitleSubtitleSwitchTableViewCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.titleLabel.apply(style: .footnoteSecondary)
                    cell?.horizontalInset = 0
                    cell?.switchView.addTarget(self, action: #selector(self.toggleEndDay), for: .valueChanged)
                    cell?.bind(title: title, isOn: isEnabled)
                    return cell
                case let .calendar(date):
                    let cell: StackingRewardDateCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.bind(date: date)
                    return cell
                }
            }
        )

        return dataSource
    }

    private func createTitleHeaderView(for tableView: UITableView) -> IconTitleHeaderView {
        let view: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        let header = R.string.localizable.stackingRewardFiltersPeriodHeader(
            preferredLanguages: selectedLocale.rLanguages)
        view.bind(title: header, icon: nil)
        view.contentInsets = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        return view
    }

    private func createActionHeaderView(for tableView: UITableView, title: String) -> StackingRewardActionControl {
        let view: StackingRewardActionControl = tableView.dequeueReusableHeaderFooterView()
        let value = R.string.localizable.stackingRewardFiltersPeriodSelectDate(
            preferredLanguages: selectedLocale.rLanguages)
        view.bind(
            title: title,
            value: value
        )
        return view
    }

    private func toggleCollapseDay(
        lens: GenericLens<StackingRewardFiltersViewModel.CustomPeriod, Bool>,
        forcedValue: Bool?
    ) {
        guard let viewModel = self.viewModel else {
            return
        }

        let newValue = forcedValue ?? !lens.get(viewModel.customPeriod)
        let updatedCustomPeriod = lens.set(newValue, viewModel.customPeriod)

        updateViewModel(viewModel: .init(
            period: viewModel.period,
            customPeriod: updatedCustomPeriod
        ))
    }

    @objc
    private func startDayAction() {
        toggleCollapseDay(lens: Lens.endDayCollapsed, forcedValue: false)
        toggleCollapseDay(lens: Lens.startDayCollapsed)
    }

    @objc
    private func endDayAction() {
        toggleCollapseDay(lens: Lens.startDayCollapsed, forcedValue: false)
        toggleCollapseDay(lens: Lens.endDayCollapsed)
    }

    @objc
    private func toggleEndDay(_ sender: UISwitch) {
        guard let viewModel = self.viewModel else {
            return
        }

        let endDayValue: StackingRewardFiltersViewModel.EndDayValue = sender.isOn ?
            .alwaysToday : .exact(nil)
        let updatedCustomPeriod = Lens.endDayValue.set(endDayValue, viewModel.customPeriod)

        updateViewModel(viewModel: .init(
            period: viewModel.period,
            customPeriod: updatedCustomPeriod
        ))
    }

    private func map(period: StackingRewardFiltersPeriod) -> StackingRewardFiltersViewModel {
        switch period {
        case .allTime:
            return .init(period: .allTime)
        case .lastWeek:
            return .init(period: .lastWeek)
        case .lastMonth:
            return .init(period: .lastMonth)
        case .lastThreeMonths:
            return .init(period: .lastThreeMonths)
        case .lastSixMonths:
            return .init(period: .lastSixMonths)
        case .lastYear:
            return .init(period: .lastYear)
        case let .custom(startDay, endDay):
            let endDayValue = viewModel?.customPeriod.endDay.value.map {
                Lens.endDayDate.set(endDay, $0)
            } ?? StackingRewardFiltersViewModel.CustomPeriod.defaultValue.endDay.value

            return .init(
                period: .custom,
                customPeriod: .init(
                    startDay: .init(
                        value: startDay,
                        isCollapsed: viewModel?.customPeriod.startDay.isCollapsed ?? false
                    ),
                    endDay: .init(
                        value: endDayValue,
                        isCollapsed: viewModel?.customPeriod.endDay.isCollapsed ?? false
                    )
                )
            )
        }
    }

    private func map(viewModel: StackingRewardFiltersViewModel) -> StackingRewardFiltersPeriod {
        switch viewModel.period {
        case .allTime:
            return .allTime
        case .lastWeek:
            return .lastWeek
        case .lastMonth:
            return .lastMonth
        case .lastThreeMonths:
            return .lastThreeMonths
        case .lastSixMonths:
            return .lastSixMonths
        case .lastYear:
            return .lastYear
        case .custom:
            return .custom(
                start: viewModel.customPeriod.startDay.value,
                end: viewModel.customPeriod.endDay.value.map { Lens.endDayDate.get($0) } ?? nil
            )
        }
    }
}

extension StackingRewardFiltersViewController: StackingRewardFiltersViewProtocol {
    func didReceive(viewModel: StackingRewardFiltersPeriod) {
        let newViewModel = map(period: viewModel)
        updateViewModel(viewModel: newViewModel)
    }

    private func updateViewModel(viewModel: StackingRewardFiltersViewModel) {
        self.viewModel = viewModel

        var snapshot = Snapshot()
        let periodSection = Section.period
        snapshot.appendSections([periodSection])

        snapshot.appendItems(
            StackingRewardFiltersViewModel.Period.allCases.map { Row.selectable(
                title: $0.name.value(for: selectedLocale),
                selected: $0.rawValue == viewModel.period.rawValue
            ) },
            toSection: periodSection
        )
        switch viewModel.period {
        case .allTime, .lastWeek, .lastMonth, .lastThreeMonths, .lastSixMonths, .lastYear:
            break
        case .custom:
            let customPeriod = viewModel.customPeriod
            let startDaySection = Section.start
            snapshot.appendSections([startDaySection])
            if !customPeriod.startDay.isCollapsed {
                snapshot.appendItems(
                    [.calendar(customPeriod.startDay.value)],
                    toSection: startDaySection
                )
            }
            snapshot.appendSections([.endAlwaysToday])
            let title = R.string.localizable.stackingRewardFiltersPeriodDateEnd(preferredLanguages: selectedLocale.rLanguages)
            switch customPeriod.endDay.value {
            case .alwaysToday, .none:
                snapshot.appendItems([.togglable(title, true)])
            case let .exact(day):
                snapshot.appendItems([.togglable(title, false)])
                let endDaySection = Section.end
                snapshot.appendSections([endDaySection])
                let isCollapsed = customPeriod.endDay.isCollapsed ?? false
                if !isCollapsed {
                    snapshot.appendItems([.calendar(day)], toSection: endDaySection)
                }
            }
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension StackingRewardFiltersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section) {
        case .period:
            return createTitleHeaderView(for: tableView)
        case .start:
            let title = R.string.localizable.stackingRewardFiltersPeriodDateStart(preferredLanguages: selectedLocale.rLanguages)
            let view = createActionHeaderView(for: tableView, title: title)
            view.control.addTarget(self, action: #selector(startDayAction), for: .touchUpInside)
            return view
        case .endAlwaysToday:
            return nil
        case .end:
            let title = R.string.localizable.stackingRewardFiltersPeriodDateEnd(preferredLanguages: selectedLocale.rLanguages)
            let view = createActionHeaderView(for: tableView, title: title)
            view.control.addTarget(self, action: #selector(endDayAction), for: .touchUpInside)
            return view
        default:
            return nil
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .period:
            return 52
        case .start, .end:
            return 44
        default:
            return 0
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .period, .endAlwaysToday:
            return 44
        case .start, .end:
            return 356
        default:
            return 0
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModel else {
            return
        }
        switch Section(rawValue: indexPath.section) {
        case .period:
            StackingRewardFiltersViewModel.Period(rawValue: indexPath.row).map {
                updateViewModel(viewModel: .init(period: $0, customPeriod: viewModel.customPeriod))
            }
        default:
            break
        }
    }
}

extension StackingRewardFiltersViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupSaveButton()
            viewModel.map {
                updateViewModel(viewModel: $0)
            }
        }
    }
}

extension StackingRewardFiltersViewController {
    enum Section: Int, Hashable {
        case period
        case start
        case endAlwaysToday
        case end
    }

    enum Row: Hashable {
        case selectable(title: String, selected: Bool)
        case togglable(String, Bool)
        case calendar(Date?)
    }
}
