import SoraFoundation

final class CurrencyViewController: UIViewController, ViewHolder {
    typealias RootViewType = CurrencyViewLayout
    typealias DataSource = UICollectionViewDiffableDataSource<CurrencyViewSectionModel, CurrencyCollectionViewCell.Model>

    let presenter: CurrencyPresenterProtocol
    private lazy var dataSource = createDataSource()

    init(presenter: CurrencyPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CurrencyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.currencyTitle()
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self
        rootView.collectionView.registerCellClass(CurrencyCollectionViewCell.self)
        rootView.collectionView.registerClass(
            CurrencyHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { collectionView, indexPath, model ->
                UICollectionViewCell? in
                let cell: CurrencyCollectionViewCell? = collectionView.dequeueReusableCell(for: indexPath)
                cell?.render(model: model)
                return cell
            }
        )

        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            let header: CurrencyHeaderView? = collectionView.dequeueReusableSupplementaryView(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                for: indexPath
            )
            let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            header?.render(title: section.title)
            return header
        }

        return dataSource
    }
}

// MARK: - UICollectionViewDelegate

extension CurrencyViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let model = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        presenter.didSelect(model: model)
    }
}

// MARK: - CurrencyViewProtocol

extension CurrencyViewController: CurrencyViewProtocol {
    func currencyListDidLoad(_ sections: [CurrencyViewSectionModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<CurrencyViewSectionModel, CurrencyCollectionViewCell.Model>()
        snapshot.appendSections(sections)
        sections.forEach { section in
            snapshot.appendItems(section.cells, toSection: section)
        }

        dataSource.apply(snapshot)
    }
}

// MARK: - Localizable

extension CurrencyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
