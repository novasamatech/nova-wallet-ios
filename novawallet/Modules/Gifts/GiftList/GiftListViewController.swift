import UIKit
import Foundation_iOS

final class GiftListViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftListViewLayout

    typealias SectionId = String
    typealias RowId = String
    typealias DataSource = UITableViewDiffableDataSource<SectionId, RowId>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SectionId, RowId>

    let presenter: GiftListPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    private var dataSource: DataSource?
    private var dataStore = DiffableDataStore<
        GiftListSectionModel.Section,
        GiftListSectionModel.Row
    >()

    private var viewModels: [GiftListSectionModel] = []

    init(
        presenter: GiftListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
        setupTableView()
    }
}

// MARK: - Private

private extension GiftListViewController {
    func createDataSource() -> DataSource {
        DataSource(
            tableView: rootView.tableView
        ) { [weak self] tableView, indexPath, model in
            guard
                let self,
                let row = self.dataStore.row(
                    rowId: model,
                    indexPath: indexPath,
                    snapshot: self.dataSource?.snapshot()
                )
            else { return UITableViewCell() }

            switch row {
            case let .header(locale):
                let cell: GiftsListHeaderTableViewCell? = tableView.dequeueReusableCell(for: indexPath)
                cell?.bind(locale: locale)
                return cell
            case let .gift(viewModel):
                let cell: GiftListGiftTableViewCell? = tableView.dequeueReusableCell(for: indexPath)
                cell?.bind(viewModel: viewModel)
                return cell
            }
        }
    }

    func setupTableView() {
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.registerClassForCell(GiftsListHeaderTableViewCell.self)
        rootView.tableView.registerClassForCell(GiftListGiftTableViewCell.self)
        dataSource = createDataSource()
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
    }

    func setupLocalization() {
        rootView.loadingView.titleLabel.text = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.giftLoadingMessage()
        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.giftsActionCreateGift()
    }

    func setupListHandlers() {
        rootView.actionButton.removeTarget(
            self,
            action: #selector(actionCreateGift),
            for: .touchUpInside
        )
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionCreateGift),
            for: .touchUpInside
        )
    }

    func setupOnboardingHandlers() {
        rootView.onboardingView.actionButton.removeTarget(
            self,
            action: #selector(actionCreateGift),
            for: .touchUpInside
        )
        rootView.onboardingView.headerView.learnMoreView.actionButton.removeTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )
        rootView.onboardingView.actionButton.addTarget(
            self,
            action: #selector(actionCreateGift),
            for: .touchUpInside
        )
        rootView.onboardingView.headerView.learnMoreView.actionButton.addTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )
    }

    @objc func actionCreateGift() {
        presenter.actionCreateGift()
    }

    @objc func actionLearnMore() {
        presenter.activateLearnMore()
    }
}

// MARK: - UITableViewDelegate

extension GiftListViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let sectionModel = dataStore.section(
            sectionNumber: indexPath.section,
            snapshot: dataSource?.snapshot()
        ) else {
            return 0
        }

        return switch sectionModel {
        case .header:
            UITableView.automaticDimension
        case .gifts:
            64
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            viewModels.count > indexPath.section,
            viewModels[indexPath.section].rows.count > indexPath.row
        else { return }

        let rowModel = viewModels[indexPath.section].rows[indexPath.row]

        presenter.selectGift(with: rowModel.identifier)
    }
}

// MARK: - GiftListViewProtocol

extension GiftListViewController: GiftListViewProtocol {
    func didReceive(listSections: [GiftListSectionModel]) {
        guard !listSections.isEmpty else { return }

        let snapshot = listSections.reduce(dataSource?.snapshot()) {
            dataStore.updating(
                section: $1.section,
                rows: $1.rows,
                in: $0
            )
        }

        guard let snapshot else { return }

        rootView.bind(loading: false)
        rootView.bind(contentModel: .list)

        setupListHandlers()

        dataSource?.apply(snapshot, animatingDifferences: false)
    }

    func didReceive(viewModel: GiftsOnboardingViewModel) {
        rootView.bind(loading: false)
        rootView.bind(contentModel: .onboarding(viewModel))

        setupOnboardingHandlers()
    }

    func didReceive(loading: Bool) {
        rootView.bind(loading: loading)
    }
}
