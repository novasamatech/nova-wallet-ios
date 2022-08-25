import UIKit
import SoraFoundation

final class YourWalletsCollectionViewCell: UICollectionViewCell {}

final class YourWalletsViewController: UIViewController, ViewHolder {
    typealias RootViewType = YourWalletsViewLayout
    typealias DataSource =
        UICollectionViewDiffableDataSource<YourWalletsViewSectionModel, YourWalletsViewModelCell>

    let presenter: YourWalletsPresenterProtocol
    private lazy var dataSource = createDataSource()

    init(
        presenter: YourWalletsPresenterProtocol,
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
        view = YourWalletsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        applyLocalization()
        presenter.setup()
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self
        rootView.collectionView.registerCellClass(YourWalletsCollectionViewCell.self)
        rootView.collectionView.registerClass(
            RoundedIconTitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { collectionView, indexPath, _ ->
                UICollectionViewCell? in
                let cell: YourWalletsCollectionViewCell? = collectionView.dequeueReusableCell(for: indexPath)
                // cell?.bind(model: model)
                return cell
            }
        )

        dataSource.supplementaryViewProvider = { [weak self] collectionView, _, indexPath in
            guard let headerModel = self?
                .dataSource
                .snapshot()
                .sectionIdentifiers[indexPath.section]
                .header else {
                return nil
            }

            let header: RoundedIconTitleCollectionHeaderView? = collectionView.dequeueReusableSupplementaryView(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                for: indexPath
            )

            header?.bind(title: headerModel.title, icon: headerModel.icon)
            return header
        }

        return dataSource
    }
}

extension YourWalletsViewController: YourWalletsViewProtocol {
    func update(viewModel: [YourWalletsViewSectionModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<YourWalletsViewSectionModel, YourWalletsViewModelCell>()
        snapshot.appendSections(viewModel)
        viewModel.forEach { section in
            snapshot.appendItems(section.cells, toSection: section)
        }

        dataSource.apply(snapshot)
    }
}

extension YourWalletsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        guard case let .common(model) = item else {
            return
        }
        presenter.didSelect(viewModel: model)
    }
}

extension YourWalletsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {}
    }
}
