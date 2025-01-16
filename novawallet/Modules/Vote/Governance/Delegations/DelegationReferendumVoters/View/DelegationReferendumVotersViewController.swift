import UIKit
import Foundation_iOS
import UIKit_iOS

final class DelegationReferendumVotersViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegationReferendumVotersViewLayout

    let presenter: DelegationReferendumVotersPresenterProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>

    typealias DataSource = UICollectionViewDiffableDataSource<
        DelegationReferendumVotersModel, DelegateSingleVoteCollectionViewCell.Model
    >

    typealias Snapshot = NSDiffableDataSourceSnapshot<
        DelegationReferendumVotersModel, DelegateSingleVoteCollectionViewCell.Model
    >

    private var state: LoadableViewModelState<[DelegationReferendumVotersModel]>?
    private var votersCount: Int?
    private var openedSectionsIds: [String] = []
    private var emptyViewTitle: String?

    private lazy var dataSource = createDataSource()

    init(
        presenter: DelegationReferendumVotersPresenterProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.quantityFormatter = quantityFormatter

        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DelegationReferendumVotersViewLayout(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        presenter.setup()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if state?.isLoading == true {
            rootView.updateLoadingState()
        }
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self

        rootView.collectionView.registerClass(
            DelegateGroupVotesHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        rootView.collectionView.registerClass(
            DelegateSingleVoteHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        rootView.collectionView.registerCellClass(DelegateSingleVoteCollectionViewCell.self)
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { collectionView, indexPath, model ->
                UICollectionViewCell? in
                let cell: DelegateSingleVoteCollectionViewCell? = collectionView.dequeueReusableCell(for: indexPath)
                cell?.bind(viewModel: model)
                let itemsCount = collectionView.numberOfItems(inSection: indexPath.section)
                let isLast = indexPath.row == itemsCount - 1
                cell?.apply(position: isLast ? .bottom : .middle)
                return cell
            }
        )

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath -> UICollectionReusableView? in
            let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            switch section {
            case let .grouped(groupModel):
                let header: DelegateGroupVotesHeader? = collectionView.dequeueReusableSupplementaryView(
                    forSupplementaryViewOfKind: kind,
                    for: indexPath
                )
                header?.id = indexPath.section
                header?.bind(viewModel: groupModel.model)
                header?.delegate = self
                return header
            case let .single(singleModel):
                let header: DelegateSingleVoteHeader? = collectionView.dequeueReusableSupplementaryView(
                    forSupplementaryViewOfKind: kind,
                    for: indexPath
                )
                header?.bind(viewModel: singleModel.model)
                header?.delegateInfoView.id = indexPath.section
                header?.delegateInfoView.delegate = self
                return header
            }
        }

        return dataSource
    }

    private func update(viewModels: [DelegationReferendumVotersModel]) {
        var snapshot = Snapshot()
        var count: Int = 0
        viewModels.forEach { viewModel in
            switch viewModel {
            case let .grouped(sectionModel):
                let section = DelegationReferendumVotersModel.grouped(sectionModel)
                snapshot.appendSections([section])
                if openedSectionsIds.contains(sectionModel.id) {
                    snapshot.appendItems(sectionModel.cells, toSection: section)
                }
                count += sectionModel.cells.count
            case let .single(sectionModel):
                let section = DelegationReferendumVotersModel.single(sectionModel)
                snapshot.appendSections([section])
                count += 1
            }
        }
        dataSource.apply(snapshot, animatingDifferences: true)
        setupCounter(value: count)
    }

    private func setupCounter(value: Int?) {
        navigationItem.rightBarButtonItem = nil

        let formatter = quantityFormatter.value(for: selectedLocale)

        guard
            let value = value,
            let valueString = formatter.string(from: value as NSNumber) else {
            return
        }

        rootView.totalVotersLabel.titleLabel.text = valueString
        rootView.totalVotersLabel.sizeToFit()

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rootView.totalVotersLabel)
        votersCount = value
    }
}

extension DelegationReferendumVotersViewController: DelegationReferendumVotersViewProtocol {
    func didReceive(viewModel: LoadableViewModelState<[DelegationReferendumVotersModel]>) {
        state = viewModel

        switch viewModel {
        case .loading:
            rootView.startLoadingIfNeeded()
        case let .loaded(viewModels), let .cached(viewModels):
            rootView.stopLoadingIfNeeded()
            update(viewModels: viewModels)
        }

        reloadEmptyState(animated: false)
    }

    func didReceive(title: String) {
        self.title = title
    }

    func didReceiveEmptyView(title: String) {
        emptyViewTitle = title
    }
}

extension DelegationReferendumVotersViewController: DelegateGroupVotesHeaderDelegate {
    func didTapOnActionControl(sender: DelegateGroupVotesHeader) {
        guard let index = sender.id, let viewModels = state?.value else {
            return
        }

        switch viewModels[safe: index] {
        case let .grouped(model):
            if let openedSectionIndex = openedSectionsIds.firstIndex(of: model.id) {
                openedSectionsIds.remove(at: openedSectionIndex)
            } else {
                openedSectionsIds.append(model.id)
            }
            update(viewModels: viewModels)
        case .single, .none:
            break
        }
    }
}

extension DelegationReferendumVotersViewController: DelegateInfoDelegate {
    func didTapOnDelegateInfo(sender: DelegateInfoView) {
        guard let index = sender.id,
              let viewModels = state?.value,
              let model = viewModels[safe: index] else {
            return
        }

        presenter.select(address: model.address)
    }
}

extension DelegationReferendumVotersViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let model = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        presenter.select(address: model.delegateInfo.addressViewModel.address)
    }
}

extension DelegationReferendumVotersViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
    var contentViewForEmptyState: UIView { rootView }
}

extension DelegationReferendumVotersViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        emptyView.image = R.image.iconEmptyHistory()
        emptyView.title = emptyViewTitle ?? ""
        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .regularFootnote
        return emptyView
    }
}

extension DelegationReferendumVotersViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case let .loaded(value), let .cached(value):
            return value.isEmpty
        case .loading, .none:
            return false
        }
    }
}

extension DelegationReferendumVotersViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupCounter(value: votersCount)
        }
    }
}
