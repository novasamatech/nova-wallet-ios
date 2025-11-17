import UIKit
import Foundation_iOS

final class GiftListViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftListViewLayout

    typealias SectionId = String
    typealias RowId = String
    typealias DataSource = UICollectionViewDiffableDataSource<SectionId, RowId>
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
        setupCollectionView()
    }
}

// MARK: - Private

private extension GiftListViewController {
    func createDataSource() -> DataSource {
        DataSource(
            collectionView: rootView.collectionView
        ) { [weak self] collectionView, indexPath, model in
            guard
                let self,
                let row = self.dataStore.row(
                    rowId: model,
                    indexPath: indexPath,
                    snapshot: self.dataSource?.snapshot()
                )
            else { return UICollectionViewCell() }

            switch row {
            case let .header(locale):
                let cell = collectionView.dequeueReusableCellWithType(
                    GiftsListHeaderTableViewCell.self,
                    for: indexPath
                )
                cell?.bind(locale: locale)
                return cell
            case let .gift(viewModel):
                let cell: GiftListGiftTableViewCell? = collectionView.dequeueReusableCell(for: indexPath)
                cell?.bind(viewModel: viewModel)
                return cell
            }
        }
    }

    func setupCollectionView() {
        rootView.collectionView.registerClass(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        rootView.collectionView.registerCellClass(GiftsListHeaderTableViewCell.self)
        rootView.collectionView.registerCellClass(GiftListGiftTableViewCell.self)
        dataSource = createDataSource()
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self
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

// MARK: - UICollectionViewDelegate

extension GiftListViewController: UICollectionViewDelegate {
    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
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
