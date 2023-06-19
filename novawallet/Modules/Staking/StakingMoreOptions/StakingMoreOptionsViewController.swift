import UIKit
import SoraFoundation

final class StakingMoreOptionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingMoreOptionsViewLayout

    let presenter: StakingMoreOptionsPresenterProtocol
    private var dAppModels: [DAppView.Model] = []
    private var moreOptionsModels: [StakingDashboardDisabledViewModel] = []

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

        setupNavigationBarStyle()
        setupCollectionView()
        setupLocalization()
        presenter.setup()
    }

    private func setupCollectionView() {
        rootView.collectionView.registerCellClass(StakingMoreOptionCollectionViewCell.self)
        rootView.collectionView.registerCellClass(DAppCollectionViewCell.self)
        rootView.collectionView.registerClass(
            TitleHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        rootView.collectionView.delegate = self
        rootView.collectionView.dataSource = self
    }

    private func setupLocalization() {
        title = R.string.localizable.multistakingMoreOptions(preferredLanguages: selectedLocale.rLanguages)
        rootView.collectionView.reloadData()
    }

    private func setupNavigationBarStyle() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = navigationBar.bounds.height
        let blurHeight = statusBarHeight + navBarHeight
        rootView.navBarBlurViewHeightConstraint.update(offset: blurHeight)
    }
}

extension StakingMoreOptionsViewController: StakingMoreOptionsViewProtocol {
    func didReceive(dAppModels: [DAppView.Model]) {
        self.dAppModels = dAppModels
        rootView.collectionView.reloadData()
    }

    func didReceive(moreOptionsModels: [StakingDashboardDisabledViewModel]) {
        self.moreOptionsModels = moreOptionsModels
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
            return moreOptionsModels.count
        case .none:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch StakingMoreOptionsSection(rawValue: indexPath.section) {
        case .dApps:
            let cell: DAppCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)!
            cell.view.bind(viewModel: dAppModels[indexPath.row])
            return cell
        case .options:
            let cell: StakingMoreOptionCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)!
            cell.view.view.bind(viewModel: moreOptionsModels[indexPath.row], locale: selectedLocale)
            return cell
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

extension StakingMoreOptionsViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch StakingMoreOptionsSection(rawValue: indexPath.section) {
        case .dApps:
            presenter.selectDApp(at: indexPath.row)
        case .options:
            presenter.selectOption(at: indexPath.row)
        case .none:
            break
        }
    }
}

extension StakingMoreOptionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
