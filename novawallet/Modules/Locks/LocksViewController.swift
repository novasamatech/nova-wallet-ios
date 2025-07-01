import UIKit

final class LocksViewController: UIViewController, ViewHolder, ModalSheetScrollViewProtocol {
    typealias RootViewType = LocksViewLayout
    typealias DataSource =
        UICollectionViewDiffableDataSource<LocksViewSectionModel, LocksViewSectionModel.CellViewModel>

    let presenter: LocksPresenterProtocol

    var scrollView: UIScrollView {
        rootView.collectionView
    }

    private lazy var dataSource = createDataSource()
    private lazy var delegate = createDelegate()
    private var viewModel: [LocksViewSectionModel] = []

    init(presenter: LocksPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = LocksViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        presenter.setup()
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = delegate

        rootView.collectionView.registerCellClass(LockCollectionViewCell.self)
        rootView.collectionView.registerClass(
            LocksHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        rootView.showHeader = { _ in true }
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { collectionView, indexPath, model -> UICollectionViewCell? in
                let cell: LockCollectionViewCell? = collectionView.dequeueReusableCell(for: indexPath)
                cell?.bind(viewModel: .init(
                    title: model.title,
                    amount: model.amount,
                    price: model.price
                )
                )
                return cell
            }
        )

        dataSource.supplementaryViewProvider = { [weak self] collectionView, _, indexPath -> UICollectionReusableView? in
            guard let headerModel = self?
                .dataSource
                .snapshot()
                .sectionIdentifiers[indexPath.section]
                .header else {
                return nil
            }

            let header: LocksHeaderView? = collectionView.dequeueReusableSupplementaryView(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                for: indexPath
            )
            header?.bind(viewModel:
                .init(
                    icon: headerModel.icon,
                    title: headerModel.title,
                    details: headerModel.details,
                    value: headerModel.value
                )
            )

            return header
        }

        return dataSource
    }

    private func createDelegate() -> UICollectionViewDelegate {
        ModalSheetCollectionViewDelegate { [weak self] _ in
            self?.presenter.didTapOnCell()
        }
    }
}

extension LocksViewController: LocksViewProtocol {
    func update(viewModel: [LocksViewSectionModel]) {
        self.viewModel = viewModel

        dataSource.apply(viewModel)
    }

    func updateHeader(title: String, value: String) {
        rootView.titleLabel.text = title
        rootView.valueLabel.text = value
    }

    func calculateEstimatedHeight(sections: Int, items: Int) -> CGFloat {
        rootView.contentHeight(sections: sections, items: items)
    }
}
