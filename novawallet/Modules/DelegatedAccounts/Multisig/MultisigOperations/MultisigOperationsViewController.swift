import UIKit
import Foundation_iOS
import Operation_iOS

final class MultisigOperationsViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigOperationsViewLayout

    let presenter: MultisigOperationsPresenterProtocol

    private lazy var dataSource: DataSource = createDataSource()

    init(
        presenter: MultisigOperationsPresenterProtocol,
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
        view = MultisigOperationsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
        setupLocalization()

        presenter.setup()
    }
}

// MARK: - Private

private extension MultisigOperationsViewController {
    func configureCollectionView() {
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self

        rootView.collectionView.registerCellClass(MultisigOperationCell.self)

        rootView.collectionView.registerClass(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
    }

    func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView
        ) { collectionView, indexPath, viewModel in
            let cell = collectionView.dequeueReusableCellWithType(
                MultisigOperationCell.self,
                for: indexPath
            )!

            cell.view.view.bind(viewModel: viewModel)

            return cell
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, _, indexPath in
            guard let headerModel = self?
                .dataSource
                .snapshot()
                .sectionIdentifiers[indexPath.section]
                .title
            else { return nil }

            let headerView: TitleCollectionHeaderView? = collectionView.dequeueReusableSupplementaryView(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                for: indexPath
            )

            headerView?.titleLabel.apply(style: .regularBodyPrimary)
            headerView?.bind(title: headerModel)

            return headerView
        }

        return dataSource
    }

    func setupLocalization() {
        title = R.string.localizable.multisigTransactionsToSign(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.locale = selectedLocale
    }

    func applySnapshot(
        with sections: [MultisigOperationSection],
        animated: Bool = false
    ) {
        var snapshot = Snapshot()

        for section in sections {
            snapshot.appendSections([section])
            snapshot.appendItems(section.operations, toSection: section)
        }

        dataSource.apply(snapshot, animatingDifferences: animated)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MultisigOperationsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return .zero }

        let width = collectionView.contentSize.width

        return if item.delegatedAccountModel != nil {
            CGSize(width: width, height: Constants.cellHeightWithFooter)
        } else {
            CGSize(width: width, height: Constants.defaultCellHeight)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection _: Int
    ) -> CGSize {
        CGSize(
            width: collectionView.frame.width,
            height: Constants.headerHeight
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let viewModel = dataSource.itemIdentifier(for: indexPath) else { return }
        presenter.selectOperation(with: viewModel.identifier)
    }
}

// MARK: - MultisigOperationsViewProtocol

extension MultisigOperationsViewController: MultisigOperationsViewProtocol {
    func didReceive(viewModel: MultisigOperationsListViewModel) {
        rootView.collectionView.refreshControl?.endRefreshing()

        switch viewModel {
        case .empty:
            rootView.showEmptyState()
            applySnapshot(with: [])
        case let .sections(sections):
            rootView.showContent()
            applySnapshot(with: sections)
        }
    }
}

// MARK: - Localizable

extension MultisigOperationsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

// MARK: - Private types

private extension MultisigOperationsViewController {
    enum Constants {
        static let defaultCellHeight: CGFloat = 96.0
        static let cellHeightWithFooter: CGFloat = 132.0
        static let headerHeight: CGFloat = 32.0
    }

    typealias DataSource = UICollectionViewDiffableDataSource<MultisigOperationSection, MultisigOperationViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<MultisigOperationSection, MultisigOperationViewModel>
}
