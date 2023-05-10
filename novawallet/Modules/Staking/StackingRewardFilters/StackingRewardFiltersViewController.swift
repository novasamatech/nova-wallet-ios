import UIKit

final class StackingRewardFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = StackingRewardFiltersViewLayout

    let presenter: StackingRewardFiltersPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private lazy var dataSource = createDataSource()
    var viewModel: StackingRewardFiltersViewModel?

    init(presenter: StackingRewardFiltersPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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
            title: "Save",
            style: .plain,
            target: self,
            action: #selector(saveButtonAction)
        )

        saveButton.setupDefaultTitleStyle(with: .regularBody)

        navigationItem.rightBarButtonItem = saveButton
    }

    @objc private func saveButtonAction() {}

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
        let header = "Show staking rewards"
        view.bind(title: header, icon: nil)
        view.contentInsets = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        return view
    }

    private func createActionHeaderView(for tableView: UITableView, title: String) -> StackingRewardActionControl {
        let view: StackingRewardActionControl = tableView.dequeueReusableHeaderFooterView()
        view.bind(title: title, value: "Select date")
        return view
    }

    @objc
    private func startDayAction() {
        guard let viewModel = viewModel,
              let currentValue = Prism.customPeriod.get(viewModel.period) else {
            return
        }

        let updatingValue = Lens.startDayCollapsed.set(!currentValue.startDay.isCollapsed, currentValue.startDay)
        let period = Lens.startDay.set(updatingValue, currentValue)
        self.viewModel?.period = Prism.customPeriod.inject(period)
        self.viewModel.map {
            updateViewModel(viewModel: $0)
        }
    }

    @objc
    private func endDayAction() {}
}

extension StackingRewardFiltersViewController: StackingRewardFiltersViewProtocol {
    func didReceive(viewModel: StackingRewardFiltersViewModel) {
        self.viewModel = viewModel
        updateViewModel(viewModel: viewModel)
    }

    private func updateViewModel(viewModel: StackingRewardFiltersViewModel) {
        var snapshot = Snapshot()
        let periodSection = Section.period
        let items: [StackingRewardFiltersViewModel.Period] = [
            .allTime,
            .lastWeek,
            .lastMonth,
            .lastThreeMonths,
            .lastSixMonths,
            .lastYear
        ]

        snapshot.appendSections([periodSection])

        snapshot.appendItems(
            items.enumerated().map { Row.selectable(title: $0.element.name, selected: $0.offset == viewModel.period.index) },
            toSection: periodSection
        )
        switch viewModel.period {
        case .allTime, .lastWeek, .lastMonth, .lastThreeMonths, .lastSixMonths, .lastYear:
            snapshot.appendItems(
                [Row.selectable(
                    title: "Custom period",
                    selected: false
                )],
                toSection: periodSection
            )
        case let .custom(customPeriod):
            snapshot.appendItems(
                [Row.selectable(title: "Custom period", selected: true)],
                toSection: periodSection
            )
            let startDaySection = Section.start
            snapshot.appendSections([startDaySection])
            if !customPeriod.startDay.isCollapsed {
                snapshot.appendItems(
                    [.calendar(customPeriod.startDay.value)],
                    toSection: startDaySection
                )
            }
            snapshot.appendSections([.endAlwaysToday])
            switch customPeriod.endDay.value {
            case .alwaysToday, .none:
                snapshot.appendItems([Row.togglable("End date is always today", true)])
            case let .exact(day):
                snapshot.appendItems([.togglable("End date is always today", false)])
                snapshot.appendSections([.end])
                let isCollapsed = customPeriod.endDay.isCollapsed ?? false
                if !isCollapsed {
                    snapshot.appendItems([.calendar(day)])
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
            let view = createActionHeaderView(for: tableView, title: "Starts")
            view.control.addTarget(self, action: #selector(startDayAction), for: .touchUpInside)
            return view
        case .endAlwaysToday:
            return nil
        case .end:
            let view = createActionHeaderView(for: tableView, title: "Ends")
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
        case .start, .endAlwaysToday, .end:
            return 44
        default:
            return 0
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section == 1 else {
            return 44
        }

        return 356
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .period:
            if let newPeriod = StackingRewardFiltersViewModel.Period(index: indexPath.row) {
                didReceive(viewModel: .init(period: newPeriod))
            }
        default:
            break
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

struct StackingRewardFiltersViewModel {
    var period: Period

    enum Period: Hashable {
        case allTime
        case lastWeek
        case lastMonth
        case lastThreeMonths
        case lastSixMonths
        case lastYear
        case custom(CustomPeriod)

        init?(index: Int) {
            switch index {
            case 0:
                self = .allTime
            case 1:
                self = .lastWeek
            case 2:
                self = .lastMonth
            case 3:
                self = .lastThreeMonths
            case 4:
                self = .lastSixMonths
            case 5:
                self = .lastYear
            case 6:
                self = .custom(.init(
                    startDay: .init(
                        value: nil,
                        isCollapsed: true
                    ),
                    endDay: .init(
                        value: nil,
                        isCollapsed: false
                    )
                ))
            default:
                return nil
            }
        }

        var index: Int {
            switch self {
            case .allTime:
                return 0
            case .lastWeek:
                return 1
            case .lastMonth:
                return 2
            case .lastThreeMonths:
                return 3
            case .lastSixMonths:
                return 4
            case .lastYear:
                return 5
            case .custom:
                return 6
            }
        }

        var name: String {
            switch self {
            case .allTime:
                return "All time"
            case .lastWeek:
                return "Last 7 days (7D)"
            case .lastMonth:
                return "Last 30 days (30D)"
            case .lastThreeMonths:
                return "Last 3 month (3M)"
            case .lastSixMonths:
                return "Last 6 months (6M)"
            case .lastYear:
                return "Last year (1Y)"
            case .custom:
                return "Custom period"
            }
        }
    }

    struct CustomPeriod: Hashable {
        let startDay: StartDay
        let endDay: EndDay
    }

    struct StartDay: Hashable {
        let value: Date?
        let isCollapsed: Bool
    }

    struct EndDay: Hashable {
        let value: EndDayValue?
        let isCollapsed: Bool
    }

    enum EndDayValue: Hashable {
        case exact(Date?)
        case alwaysToday
    }
}

extension StackingRewardFiltersViewController {
    enum Prism {
        static var customPeriod: GenericPrism<StackingRewardFiltersViewModel.Period, StackingRewardFiltersViewModel.CustomPeriod> {
            .init(
                get: {
                    guard case let .custom(period) = $0 else {
                        return nil
                    }
                    return period
                },
                inject: { .custom($0) }
            )
        }
    }

    enum Lens {
        static let startDay = GenericLens<
            StackingRewardFiltersViewModel.CustomPeriod,
            StackingRewardFiltersViewModel.StartDay
        >(
            get: { $0.startDay },
            set: { .init(startDay: $0, endDay: $1.endDay) }
        )
        static let startDayCollapsed = GenericLens<StackingRewardFiltersViewModel.StartDay, Bool>(
            get: { $0.isCollapsed },
            set: { StackingRewardFiltersViewModel.StartDay(value: $1.value, isCollapsed: $0) }
        )
        static let endDayCollapsed = GenericLens<StackingRewardFiltersViewModel.EndDay, Bool>(
            get: { $0.isCollapsed },
            set: { StackingRewardFiltersViewModel.EndDay(value: $1.value, isCollapsed: $0) }
        )
    }
}

struct GenericLens<Whole, Part> {
    let get: (Whole) -> Part
    let set: (Part, Whole) -> Whole
}

struct GenericPrism<Whole, Part> {
    let get: (Whole) -> Part?
    let inject: (Part) -> Whole

    init(get: @escaping (Whole) -> Part?, inject: @escaping (Part) -> Whole) {
        self.get = get
        self.inject = inject
    }

    func then<Subpart>(_ other: GenericPrism<Part, Subpart>) -> GenericPrism<Whole, Subpart> {
        GenericPrism<Whole, Subpart>(
            get: { self.get($0).flatMap(other.get) },
            inject: { self.inject(other.inject($0)) }
        )
    }
}
