import UIKit
import SoraFoundation
import SoraUI
import SubstrateSdk

final class YourWalletsViewController: UIViewController, ViewHolder {
    typealias RootViewType = YourWalletsViewLayout
    typealias DataSource =
        UICollectionViewDiffableDataSource<YourWalletsViewSectionModel, YourWalletsCellViewModel>

    let presenter: YourWalletsPresenterProtocol
    private lazy var dataSource = createDataSource()

    init(presenter: YourWalletsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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
        presenter.setup()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.viewDidDisappear()
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self
        rootView.collectionView.registerCellClass(SelectableIconSubtitleCollectionViewCell.self)
        rootView.collectionView.registerClass(
            RoundedIconTitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { collectionView, indexPath, model ->
                UICollectionViewCell? in
                let cell: SelectableIconSubtitleCollectionViewCell? = collectionView.dequeueReusableCell(for: indexPath)
                switch model {
                case let .warning(warning):
                    cell?.bind(model: Self.mapWarningModel(warning))
                case let .common(commonModel):
                    cell?.bind(model: Self.mapCommonModel(commonModel))
                }
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
            header?.bind(viewModel: .init(title: headerModel.title, icon: headerModel.icon))
            return header
        }

        return dataSource
    }

    private static func mapWarningModel(_ model: YourWalletsCellViewModel.WarningModel) ->
        SelectableIconSubtitleCollectionViewCell.Model {
        .init(
            iconSubtitle: .init(
                icon: model.imageViewModel,
                title: model.accountName ?? "",
                subtitle: model.warning,
                subtitleIcon: DrawableIconViewModel(icon: R.image.iconWarning()!),
                lineBreakMode: .byTruncatingTail
            ),
            isSelected: nil
        )
    }

    private static func mapCommonModel(_ model: YourWalletsCellViewModel.CommonModel) ->
        SelectableIconSubtitleCollectionViewCell.Model {
        .init(
            iconSubtitle: .init(
                icon: model.imageViewModel,
                title: model.displayAddress.username,
                subtitle: model.displayAddress.address,
                subtitleIcon: model.chainIcon,
                lineBreakMode: .byTruncatingMiddle
            ),
            isSelected: model.isSelected
        )
    }
}

// MARK: - YourWalletsViewProtocol

extension YourWalletsViewController: YourWalletsViewProtocol {
    func update(viewModel: [YourWalletsViewSectionModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<YourWalletsViewSectionModel, YourWalletsCellViewModel>()
        snapshot.appendSections(viewModel)
        viewModel.forEach { section in
            snapshot.appendItems(section.cells, toSection: section)
        }

        dataSource.apply(snapshot)
    }

    func update(header: String) {
        rootView.header.bind(title: header, icon: nil)
    }
}

// MARK: - UICollectionViewDelegate

extension YourWalletsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case let .common(viewModel) = item else {
            return
        }

        presenter.didSelect(viewModel: viewModel)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }
}

// MARK: - ModalSheetPresenterDelegate

extension YourWalletsViewController: ModalSheetPresenterDelegate {
    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool {
        let offset = rootView.collectionView.contentOffset.y + rootView.collectionView.contentInset.top
        return offset == 0
    }
}
