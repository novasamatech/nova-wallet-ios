import UIKit

final class DelegationReferendumVotersViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegationReferendumVotersViewLayout

    let presenter: DelegationReferendumVotersPresenterProtocol
    typealias DataSource = UICollectionViewDiffableDataSource<DelegationReferendumVotersModel, DelegateSingleVoteCollectionViewCell.Model>
    typealias Snapshot = NSDiffableDataSourceSnapshot<DelegationReferendumVotersModel, DelegateSingleVoteCollectionViewCell.Model>
    private var viewModels: [DelegationReferendumVotersModel] = []
    private var openedSectionsIds: [String] = []

    private lazy var dataSource = createDataSource()

    init(presenter: DelegationReferendumVotersPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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

        rootView.showHeader = { _ in true }
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { collectionView, indexPath, model ->
                UICollectionViewCell? in
                let cell: DelegateSingleVoteCollectionViewCell? = collectionView.dequeueReusableCell(for: indexPath)
                cell?.bind(viewModel: model)
                let isLast = indexPath.row == collectionView.numberOfItems(inSection: indexPath.section) - 1
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
        viewModels.forEach { viewModel in
            switch viewModel {
            case let .grouped(sectionModel):
                let section = DelegationReferendumVotersModel.grouped(sectionModel)
                snapshot.appendSections([section])
                if openedSectionsIds.contains(sectionModel.id) {
                    snapshot.appendItems(sectionModel.cells, toSection: section)
                }
            case let .single(sectionModel):
                let section = DelegationReferendumVotersModel.single(sectionModel)
                snapshot.appendSections([section])
            }
        }
        self.viewModels = viewModels
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension DelegationReferendumVotersViewController: DelegationReferendumVotersViewProtocol {
    func didReceive(viewModels: [DelegationReferendumVotersModel]) {
        update(viewModels: viewModels)
    }

    func didReceive(title: String) {
        self.title = title
    }
}

extension DelegationReferendumVotersViewController: DelegateGroupVotesHeaderDelegate {
    func didTapOnActionControl(sender: DelegateGroupVotesHeader) {
        guard let index = sender.id else {
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
        guard let index = sender.id, let model = viewModels[safe: index] else {
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
