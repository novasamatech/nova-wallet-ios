import UIKit
import SoraFoundation

final class StakingRewardFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardFiltersViewLayout

    let presenter: StakingRewardFiltersPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private var dataSource: DataSource?
    var viewModel: StakingRewardFiltersViewModel?
    let dateFormatter: LocalizableResource<DateFormatter>
    let calendar: Calendar

    init(
        presenter: StakingRewardFiltersPresenterProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        localizationManager: LocalizationManagerProtocol,
        calendar: Calendar = .current
    ) {
        self.presenter = presenter
        self.dateFormatter = dateFormatter
        self.calendar = calendar

        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingRewardFiltersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupSaveButton()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.registerHeaderFooterView(withClass: StakingRewardActionControl.self)
        rootView.tableView.registerClassForCell(SelectableFilterCell.self)
        rootView.tableView.registerClassForCell(TitleSubtitleSwitchTableViewCell.self)
        rootView.tableView.registerClassForCell(StakingRewardDateCell.self)
        dataSource = createDataSource()
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
    }

    private func setupSaveButton(isEnabled: Bool = true) {
        let saveButton = UIBarButtonItem(
            title: R.string.localizable.commonSave(preferredLanguages: selectedLocale.rLanguages),
            style: .plain,
            target: self,
            action: #selector(saveButtonAction)
        )

        saveButton.isEnabled = isEnabled
        saveButton.setupDefaultTitleStyle(with: .regularBody)
        navigationItem.rightBarButtonItem = saveButton
    }

    @objc private func saveButtonAction() {
        guard let viewModel = viewModel, let period = map(viewModel: viewModel) else {
            return
        }
        presenter.save(period)
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            tableView: rootView.tableView,
            cellProvider: { tableView, indexPath, model ->
                UITableViewCell? in
                switch model {
                case let .selectable(title, selected):
                    let cell: SelectableFilterCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.bind(viewModel: .init(underlyingViewModel: title, selectable: selected))
                    return cell
                case let .dateAlwaysToday(title, enabled):
                    let cell: TitleSubtitleSwitchTableViewCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.titleLabel.apply(style: .footnoteSecondary)
                    cell?.horizontalInset = 16
                    cell?.switchView.addTarget(self, action: #selector(self.toggleEndDay), for: .valueChanged)
                    cell?.bind(title: title, isOn: enabled)
                    return cell
                case let .calendar(id, date, minDate, maxDate):
                    let cell: StakingRewardDateCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.bind(date: date, minDate: minDate, maxDate: maxDate)
                    cell?.id = id.rawValue
                    cell?.delegate = self
                    return cell
                }
            }
        )

        return dataSource
    }

    private func createTitleHeaderView(for tableView: UITableView) -> IconTitleHeaderView {
        let view: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        let header = R.string.localizable.stakingRewardFiltersPeriodHeader(
            preferredLanguages: selectedLocale.rLanguages)
        view.bind(title: header, icon: nil)
        view.contentInsets = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        return view
    }

    private func createActionHeaderView(
        for tableView: UITableView,
        title: String,
        value: String,
        activated: Bool
    ) -> StakingRewardActionControl {
        let view: StakingRewardActionControl = tableView.dequeueReusableHeaderFooterView()
        view.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.bind(
            title: title,
            value: value,
            activated: activated
        )
        return view
    }

    private func collapseOrExpandCalendar(
        lens: GenericLens<StakingRewardFiltersViewModel.CustomPeriod, Bool>,
        forceCollapse: Bool? = nil
    ) {
        guard let viewModel = self.viewModel else {
            return
        }

        let newValue = forceCollapse ?? !lens.get(viewModel.customPeriod)
        let updatedCustomPeriod = lens.set(newValue, viewModel.customPeriod)

        updateViewModel(viewModel: .init(
            period: viewModel.period,
            customPeriod: updatedCustomPeriod
        ))
    }

    @objc
    private func startDayAction() {
        collapseOrExpandCalendar(lens: Lens.endDayCollapsed, forceCollapse: true)
        collapseOrExpandCalendar(lens: Lens.startDayCollapsed)
    }

    @objc
    private func endDayAction() {
        collapseOrExpandCalendar(lens: Lens.startDayCollapsed, forceCollapse: true)
        collapseOrExpandCalendar(lens: Lens.endDayCollapsed)
    }

    @objc
    private func toggleEndDay(_ sender: UISwitch) {
        guard let viewModel = self.viewModel else {
            return
        }

        let endDayValue: StakingRewardFiltersViewModel.EndDayValue = sender.isOn ?
            .alwaysToday : .exact(nil)
        let updatedCustomPeriod = Lens.endDayValue.set(endDayValue, viewModel.customPeriod)

        updateViewModel(viewModel: .init(
            period: viewModel.period,
            customPeriod: updatedCustomPeriod
        ))
    }

    private func map(period: StakingRewardFiltersPeriod) -> StakingRewardFiltersViewModel {
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
        case let .custom(customDate):
            let startDate: Date
            let endDate: StakingRewardFiltersViewModel.EndDayValue?

            switch customDate {
            case let .interval(start, end):
                startDate = start
                endDate = .exact(end)
            case let .openEndDate(start):
                startDate = start
                endDate = .alwaysToday
            }

            return .init(
                period: .custom,
                customPeriod: .init(
                    startDay: .init(
                        value: startDate,
                        collapsed: viewModel?.customPeriod.startDay.collapsed ?? true
                    ),
                    endDay: .init(
                        value: endDate,
                        collapsed: viewModel?.customPeriod.endDay.collapsed ?? true
                    )
                )
            )
        }
    }

    private func map(viewModel: StakingRewardFiltersViewModel) -> StakingRewardFiltersPeriod? {
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
            switch viewModel.customPeriod.endDay.value {
            case .alwaysToday:
                if let startDate = viewModel.customPeriod.startDay.value {
                    return .custom(.openEndDate(startDate: startDate))
                } else {
                    return nil
                }
            case let .exact(date):
                guard let exactDate = date, let startDate = viewModel.customPeriod.startDay.value else {
                    return nil
                }
                return .custom(.interval(startDate, exactDate))
            case .none:
                return nil
            }
        }
    }

    private func dateStringValue(_ date: Date?) -> String {
        guard let date = date else {
            return R.string.localizable.stakingRewardFiltersPeriodSelectDate(
                preferredLanguages: selectedLocale.rLanguages)
        }

        return dateFormatter.value(for: selectedLocale).string(from: date)
    }

    private func updateViewModel(viewModel: StakingRewardFiltersViewModel) {
        self.viewModel = viewModel
        var snapshot = Snapshot()

        setupSaveButton(isEnabled: map(viewModel: viewModel) != nil)
        let periodSection = Section.period
        snapshot.appendSections([periodSection])
        snapshot.appendItems(
            StakingRewardFiltersViewModel.Period.allCases.map {
                Row.selectable(
                    title: $0.name.value(for: selectedLocale),
                    selected: $0.rawValue == viewModel.period.rawValue
                )
            },
            toSection: periodSection
        )

        guard viewModel.period == .custom else {
            dataSource?.apply(snapshot, animatingDifferences: false)
            return
        }

        let customPeriod = viewModel.customPeriod
        let selectDateValue = dateStringValue(viewModel.customPeriod.startDay.value)
        let startDaySection = Section.start(date: selectDateValue, active: !customPeriod.startDay.collapsed)
        let endDate = Lens.endDayValue.get(viewModel.customPeriod).map(Lens.endDayDate.get) ?? nil
        let startDate = customPeriod.startDay.value
        snapshot.appendSections([startDaySection])
        if !customPeriod.startDay.collapsed {
            snapshot.appendItems(
                [.calendar(
                    .startDate,
                    date: startDate,
                    minDate: nil,
                    maxDate: calendar.startOfDay(for: endDate ?? Date()).addingTimeInterval(-1)
                )],
                toSection: startDaySection
            )
        }

        snapshot.appendSections([.endAlwaysToday])
        let title = R.string.localizable.stakingRewardFiltersPeriodEndDateOpen(
            preferredLanguages: selectedLocale.rLanguages)
        switch customPeriod.endDay.value {
        case .alwaysToday, .none:
            snapshot.appendItems([.dateAlwaysToday(title, true)])
        case let .exact(day):
            snapshot.appendItems([.dateAlwaysToday(title, false)])
            let dateValue = dateStringValue(endDate ?? nil)
            let collapsed = customPeriod.endDay.collapsed
            let endDaySection = Section.end(date: dateValue, active: !collapsed)
            snapshot.appendSections([endDaySection])
            if !collapsed {
                let minDate = startDate.map { calendar.startOfDay(for: $0) }?.addingTimeInterval(.secondsInDay) ?? calendar.startOfDay(for: Date())
                snapshot.appendItems([.calendar(
                    .endDate,
                    date: day,
                    minDate: minDate,
                    maxDate: nil
                )], toSection: endDaySection)
            }
        }

        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

extension StakingRewardFiltersViewController: StakingRewardFiltersViewProtocol {
    func didReceive(viewModel: StakingRewardFiltersPeriod) {
        let newViewModel = map(period: viewModel)
        updateViewModel(viewModel: newViewModel)
    }
}

extension StakingRewardFiltersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionModel = dataSource?.snapshot().sectionIdentifiers[section]
        switch sectionModel {
        case .period:
            return createTitleHeaderView(for: tableView)
        case let .start(date, activated):
            let title = R.string.localizable.stakingRewardFiltersPeriodDateStart(
                preferredLanguages: selectedLocale.rLanguages)
            let view = createActionHeaderView(for: tableView, title: title, value: date, activated: activated)
            view.control.addTarget(self, action: #selector(startDayAction), for: .touchUpInside)
            return view
        case .endAlwaysToday:
            return nil
        case let .end(date, activated):
            let title = R.string.localizable.stakingRewardFiltersPeriodDateEnd(
                preferredLanguages: selectedLocale.rLanguages)
            let view = createActionHeaderView(for: tableView, title: title, value: date, activated: activated)
            view.control.addTarget(self, action: #selector(endDayAction), for: .touchUpInside)
            return view
        default:
            return nil
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionModel = dataSource?.snapshot().sectionIdentifiers[section]
        switch sectionModel {
        case .period:
            return 52
        case .start, .end:
            return 24
        default:
            return 0
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionModel = dataSource?.snapshot().sectionIdentifiers[indexPath.section]
        switch sectionModel {
        case .period, .endAlwaysToday:
            return 44
        case .start, .end:
            return 356
        default:
            return 0
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModel,
              let period = StakingRewardFiltersViewModel.Period(rawValue: indexPath.row) else {
            return
        }

        updateViewModel(viewModel: .init(period: period, customPeriod: viewModel.customPeriod))
    }
}

extension StakingRewardFiltersViewController: StakingRewardDateCellDelegate {
    func datePicker(id: String, selectedDate: Date) {
        guard let viewModel = viewModel, let calendarIdentifier = CalendarIdentifier(rawValue: id) else {
            return
        }
        let date = calendar.startOfDay(for: selectedDate)
        let updatedPeriod: StakingRewardFiltersViewModel.CustomPeriod
        switch calendarIdentifier {
        case .startDate:
            updatedPeriod = Lens.startDayValue.set(date, viewModel.customPeriod)
        case .endDate:
            let endDate = Lens.endDayValue.get(viewModel.customPeriod).map {
                Lens.endDayDate.set(date, $0)
            }

            updatedPeriod = Lens.endDayValue.set(endDate, viewModel.customPeriod)
        }

        updateViewModel(viewModel: .init(
            period: viewModel.period,
            customPeriod: updatedPeriod
        ))
    }
}

extension StakingRewardFiltersViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupSaveButton()
            viewModel.map {
                updateViewModel(viewModel: $0)
            }
        }
    }
}