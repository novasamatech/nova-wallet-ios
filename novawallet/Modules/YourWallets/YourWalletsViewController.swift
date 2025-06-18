import UIKit
import Foundation_iOS
import UIKit_iOS
import SubstrateSdk

final class YourWalletsViewController: UIViewController, ViewHolder, ModalSheetScrollViewProtocol {
    var scrollView: UIScrollView {
        rootView.collectionView
    }

    typealias RootViewType = YourWalletsViewLayout
    typealias DataSource =
        UICollectionViewDiffableDataSource<YourWalletsViewSectionModel, YourWalletsCellViewModel>

    let presenter: YourWalletsPresenterProtocol
    private lazy var dataSource = createDataSource()
    private lazy var delegate = createDelegate()
    private var viewModel: [YourWalletsViewSectionModel] = []

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.viewWillDisappear()
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = delegate

        rootView.collectionView.registerCellClass(SelectableIconSubtitleCollectionViewCell.self)
        rootView.collectionView.registerClass(
            RoundedIconTitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        rootView.showHeader = { [weak self] section in
            self?.viewModel[section].header != nil
        }
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
            header?.contentInsets = .init(top: 16, left: 0, bottom: 8, right: 0)
            return header
        }

        return dataSource
    }

    private func createDelegate() -> UICollectionViewDelegate {
        ModalSheetCollectionViewDelegate(
            selectItemClosure: { [weak self] indexPath in
                guard let self = self else {
                    return
                }
                guard let item = self.dataSource.itemIdentifier(for: indexPath),
                      case let .common(viewModel) = item else {
                    return
                }
                self.presenter.didSelect(viewModel: viewModel)
            }
        )
    }

    private static func mapWarningModel(_ model: YourWalletsCellViewModel.WarningModel) ->
        SelectableIconSubtitleCollectionViewCell.Model {
        .init(
            icon: model.imageViewModel,
            title: model.accountName ?? "",
            subtitle: model.warning,
            subtitleIcon: DrawableIconViewModel(icon: R.image.iconWarning()!),
            lineBreakMode: .byTruncatingTail,
            isSelected: nil
        )
    }

    private static func mapCommonModel(_ model: YourWalletsCellViewModel.CommonModel) ->
        SelectableIconSubtitleCollectionViewCell.Model {
        .init(
            icon: model.imageViewModel,
            title: model.displayAddress.username,
            subtitle: model.displayAddress.address,
            subtitleIcon: model.chainIcon,
            lineBreakMode: .byTruncatingMiddle,
            isSelected: model.isSelected
        )
    }
}

// MARK: - YourWalletsViewProtocol

extension YourWalletsViewController: YourWalletsViewProtocol {
    func update(viewModel: [YourWalletsViewSectionModel]) {
        self.viewModel = viewModel

        dataSource.apply(viewModel)
    }

    func update(header: String) {
        rootView.header.text = header
    }

    func calculateEstimatedHeight(sections: Int, items: Int) -> CGFloat {
        rootView.contentHeight(sections: sections, items: items)
    }
}
