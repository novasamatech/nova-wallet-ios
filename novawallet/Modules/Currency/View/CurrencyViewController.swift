import UIKit

final class CurrencyViewController: UIViewController, ViewHolder {
    typealias RootViewType = CurrencyViewLayout

    let presenter: CurrencyPresenterProtocol
    private lazy var dataSource = makeDataSource()
    typealias DataSource = UICollectionViewDiffableDataSource<
        CurrencyViewSectionModel,
        CurrencyRow.Model
    >

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
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self
        rootView.collectionView.registerCellClass(CurrencyRow.self)
        rootView.collectionView.registerClass(
            CurrencyHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }

    func makeDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { (collectionView, indexPath, model) ->
                UICollectionViewCell? in
                let cell: CurrencyRow? = collectionView.dequeueReusableCell(for: indexPath)
                cell?.render(model: model)
                return cell
            }
        )

        dataSource.supplementaryViewProvider = { (
            collectionView: UICollectionView,
            _: String,
            indexPath: IndexPath
        ) -> UICollectionReusableView? in
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

extension CurrencyViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let model = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
    }
}

extension CurrencyViewController: CurrencyViewProtocol {
    func currencyListDidLoad(_ sections: [CurrencyViewSectionModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<CurrencyViewSectionModel, CurrencyRow.Model>()
        snapshot.appendSections(sections)
        sections.forEach { section in
            snapshot.appendItems(section.cells, toSection: section)
        }

        dataSource.apply(snapshot)
    }
}

struct CurrencyViewSectionModel: Hashable {
    var title: String
    var cells: [CurrencyRow.Model]
}

final class CurrencyHeaderView: UICollectionReusableView {
    lazy var titleLabel: UILabel = .create {
        $0.font = R.font.publicSansRegular(size: 13)
        $0.textColor = R.color.colorWhite64()
    }

    func render(title: String) {
        titleLabel.text = title
    }
}
