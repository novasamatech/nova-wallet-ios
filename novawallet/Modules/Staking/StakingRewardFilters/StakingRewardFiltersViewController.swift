import UIKit
import Foundation
import Foundation_iOS
import Operation_iOS

final class StakingRewardFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardFiltersViewLayout
    typealias SectionId = String
    typealias RowId = String

    let presenter: StakingRewardFiltersPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<SectionId, RowId>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SectionId, RowId>
    private var dataSource: DataSource?
    private var dataStore = DiffableDataStore<Section, Row>()
    private var viewModel: StakingRewardFiltersViewModel?

    var initialViewModel: StakingRewardFiltersViewModel?
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
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSave(),
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
            cellProvider: { [weak self] tableView, indexPath, model ->
                UITableViewCell? in
                guard let self = self,
                      let row = self.dataStore.row(
                          rowId: model,
                          indexPath: indexPath,
                          snapshot: self.dataSource?.snapshot()
                      ) else {
                    return UITableViewCell()
                }

                switch row {
                case let .selectable(title, selected):
                    let cell: SelectableFilterCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.bind(viewModel: .init(underlyingViewModel: title, selectable: selected))
                    return cell
                case let .dateAlwaysToday(title, enabled):
                    let cell: TitleSubtitleSwitchTableViewCell? = tableView.dequeueReusableCell(for: indexPath)
                    cell?.titleLabel.apply(style: .footnoteSecondary)
                    cell?.horizontalInset = 16
                    cell?.switchView.removeTarget(nil, action: nil, for: .allEvents)
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
        let header = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingRewardFiltersPeriodHeader()
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
        view.control.removeTarget(nil, action: nil, for: .allEvents)
        view.bind(
            title: title,
            value: value,
            activated: activated
        )
        return view
    }

    @objc
    private func startDayAction() {
        guard var viewModel = self.viewModel else {
            return
        }
        let collapsedStartDayCalendar = viewModel.customPeriod.startDay.collapsed
        let needDefaultDate = collapsedStartDayCalendar && viewModel.customPeriod.startDay.value == nil

        viewModel.customPeriod = .init(
            startDay: .init(
                value: needDefaultDate ? calendar.startOfDay(for: Date()) : viewModel.customPeriod.startDay.value,
                collapsed: !viewModel.customPeriod.startDay.collapsed
            ),
            endDay: .init(
                value: viewModel.customPeriod.endDay.value,
                collapsed: true
            )
        )
        updateViewModel(viewModel: viewModel)
    }

    @objc
    private func endDayAction() {
        guard var viewModel = self.viewModel else {
            return
        }
        let newValue = correctedDefaultDate(
            endDay: viewModel.customPeriod.endDay,
            expandedCalendar: viewModel.customPeriod.endDay.collapsed
        )
        viewModel.customPeriod = .init(
            startDay: .init(
                value: viewModel.customPeriod.startDay.value,
                collapsed: true
            ),
            endDay: .init(
                value: newValue,
                collapsed: !viewModel.customPeriod.endDay.collapsed
            )
        )
        updateViewModel(viewModel: viewModel)
    }

    private func correctedDefaultDate(
        endDay: StakingRewardFiltersViewModel.EndDay,
        expandedCalendar: Bool
    ) -> StakingRewardFiltersViewModel.EndDayValue? {
        if expandedCalendar,
           let endDay = endDay.value,
           Lens.endDayDate.get(endDay) == nil,
           let date = calendar.endOfDay(for: Date()) {
            return Lens.endDayDate.set(date, endDay)
        }

        return endDay.value
    }

    @objc
    private func toggleEndDay(_ sender: UISwitch) {
        guard let viewModel = self.viewModel else {
            return
        }

        let date = viewModel.customPeriod.endDay.collapsed ? nil : calendar.endOfDay(for: Date())

        let endDayValue: StakingRewardFiltersViewModel.EndDayValue = sender.isOn ?
            .alwaysToday : .exact(date)
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
            return R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingRewardFiltersPeriodSelectDate()
        }

        return dateFormatter.value(for: selectedLocale).string(from: date)
    }

    private func updateViewModel(viewModel: StakingRewardFiltersViewModel) {
        self.viewModel = viewModel
        let canSave = map(viewModel: viewModel) != nil && viewModel != initialViewModel
        setupSaveButton(isEnabled: canSave)

        let periodRows = StakingRewardFiltersViewModel.Period.allCases.map {
            Row.selectable(
                title: $0.name.value(for: selectedLocale),
                selected: $0.rawValue == viewModel.period.rawValue
            )
        }

        var snapshot = dataStore.updating(
            section: Section.period,
            rows: periodRows,
            in: dataSource?.snapshot()
        )

        guard viewModel.period == .custom else {
            snapshot = dataStore.removing(
                sections: [
                    Section.startDateIdentifier,
                    Section.endAlwaysTodayIdentifier,
                    Section.endDateIdentifier
                ],
                from: snapshot
            )
            dataSource?.apply(snapshot, animatingDifferences: false)
            return
        }

        let customPeriod = viewModel.customPeriod
        let selectDateValue = dateStringValue(viewModel.customPeriod.startDay.value)
        let startDaySection = Section.start(date: selectDateValue, active: !customPeriod.startDay.collapsed)
        let endDate = Lens.endDayValue.get(viewModel.customPeriod).map(Lens.endDayDate.get) ?? nil
        let startDate = customPeriod.startDay.value

        let calendarRow: [Row] = [
            .calendar(
                .startDate,
                date: startDate,
                minDate: nil,
                maxDate: calendar.startOfDay(for: endDate ?? Date())
            )
        ]

        snapshot = dataStore.updating(
            section: startDaySection,
            rows: !customPeriod.startDay.collapsed ? calendarRow : [],
            in: snapshot
        )

        let title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingRewardFiltersPeriodEndDateOpen()
        switch customPeriod.endDay.value {
        case .alwaysToday, .none:
            snapshot = dataStore.updating(
                section: .endAlwaysToday,
                rows: [.dateAlwaysToday(title, true)],
                in: snapshot
            )
            snapshot = dataStore.removing(sections: [Section.endDateIdentifier], from: snapshot)
        case let .exact(day):
            snapshot = dataStore.updating(
                section: .endAlwaysToday,
                rows: [.dateAlwaysToday(title, false)],
                in: snapshot
            )
            let dateValue = dateStringValue(endDate ?? nil)
            let collapsed = customPeriod.endDay.collapsed
            var items: [Row] = []

            if !collapsed {
                let minDate = startDate.map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: Date())
                items = [
                    .calendar(
                        .endDate,
                        date: day,
                        minDate: minDate,
                        maxDate: nil
                    )
                ]
            }

            snapshot = dataStore.updating(
                section: Section.end(date: dateValue, active: !collapsed),
                rows: items,
                in: snapshot
            )
        }

        dataSource?.apply(snapshot, animatingDifferences: false)
    }
}

extension StakingRewardFiltersViewController: StakingRewardFiltersViewProtocol {
    func didReceive(viewModel: StakingRewardFiltersPeriod) {
        let newViewModel = map(period: viewModel)

        initialViewModel = newViewModel

        updateViewModel(viewModel: newViewModel)
    }
}

extension StakingRewardFiltersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionModel = dataStore.section(
            sectionNumber: section,
            snapshot: dataSource?.snapshot()
        ) else {
            return nil
        }
        switch sectionModel {
        case .period:
            return createTitleHeaderView(for: tableView)
        case let .start(date, activated):
            let title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingRewardFiltersPeriodDateStart()
            let view = createActionHeaderView(for: tableView, title: title, value: date, activated: activated)
            view.control.addTarget(self, action: #selector(startDayAction), for: .touchUpInside)
            return view
        case .endAlwaysToday:
            return nil
        case let .end(date, activated):
            let title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingRewardFiltersPeriodDateEnd()
            let view = createActionHeaderView(for: tableView, title: title, value: date, activated: activated)
            view.control.addTarget(self, action: #selector(endDayAction), for: .touchUpInside)
            return view
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionModel = dataStore.section(
            sectionNumber: section,
            snapshot: dataSource?.snapshot()
        ) else {
            return 0
        }
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
        guard let sectionModel = dataStore.section(
            sectionNumber: indexPath.section,
            snapshot: dataSource?.snapshot()
        ) else {
            return 0
        }
        switch sectionModel {
        case .period, .endAlwaysToday:
            return 44
        case .start, .end:
            return 356
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

        let updatedPeriod: StakingRewardFiltersViewModel.CustomPeriod
        switch calendarIdentifier {
        case .startDate:
            let date = calendar.startOfDay(for: selectedDate)
            updatedPeriod = .init(
                startDay: .init(
                    value: date,
                    collapsed: true
                ),
                endDay: viewModel.customPeriod.endDay
            )
        case .endDate:
            guard let date = calendar.endOfDay(for: selectedDate) else {
                return
            }
            let endDate = Lens.endDayValue.get(viewModel.customPeriod).map {
                Lens.endDayDate.set(date, $0)
            }

            updatedPeriod = .init(
                startDay: viewModel.customPeriod.startDay,
                endDay: .init(value: endDate, collapsed: true)
            )
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
