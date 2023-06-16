import UIKit
import SoraFoundation

final class StakingMoreOptionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingMoreOptionsViewLayout

    let presenter: StakingMoreOptionsPresenterProtocol
    private var dAppModels: [ReferendumDAppView.Model] = []

    init(
        presenter: StakingMoreOptionsPresenterProtocol,
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
        view = StakingMoreOptionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        presenter.setup()
    }

    private func setupCollectionView() {
        rootView.collectionView.registerCellClass(DAppCollectionViewCell.self)
        rootView.collectionView.registerClass(
            TitleHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        rootView.collectionView.delegate = self
        rootView.collectionView.dataSource = self
    }
}

extension StakingMoreOptionsViewController: StakingMoreOptionsViewProtocol {
    func didReceive(dAppModels: [ReferendumDAppView.Model]) {
        self.dAppModels = dAppModels
        rootView.collectionView.reloadData()
    }
}

extension StakingMoreOptionsViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        StakingMoreOptionsSection.allCases.count
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch StakingMoreOptionsSection(rawValue: section) {
        case .dApps:
            return dAppModels.count
        case .options:
            return 0
        case .none:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch StakingMoreOptionsSection(rawValue: indexPath.section) {
        case .dApps:
            let cell: DAppCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)!
            cell.bodyView.bind(viewModel: dAppModels[indexPath.row])
            return cell
        case .options:
            return UICollectionViewCell()
        case .none:
            return UICollectionViewCell()
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch StakingMoreOptionsSection(rawValue: indexPath.section) {
        case .dApps:
            let header: TitleHeaderView? = collectionView.dequeueReusableSupplementaryView(
                forSupplementaryViewOfKind: kind,
                for: indexPath
            )
            header?.bind(title: R.string.localizable.stakingMoreOptionsDAppsTitle(preferredLanguages: selectedLocale.rLanguages))
            header?.titleLabel.apply(style: .title3Primary)
            return header ?? .init()
        case .options, .none:
            return .init()
        }
    }
}

extension StakingMoreOptionsViewController: UICollectionViewDelegate {}

extension StakingMoreOptionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}
