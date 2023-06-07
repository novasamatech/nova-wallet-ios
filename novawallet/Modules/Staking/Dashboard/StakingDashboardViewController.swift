import UIKit
import SoraFoundation

final class StakingDashboardViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingDashboardViewLayout

    let presenter: StakingDashboardPresenterProtocol

    init(
        presenter: StakingDashboardPresenterProtocol,
        localizationManager _: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingDashboardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()

        presenter.setup()
    }

    private func setupLocalization() {}

    private func setupCollectionView() {
        rootView.collectionView.registerCellClass(WalletSwitchCollectionViewCell.self)

        rootView.collectionView.registerClass(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        rootView.collectionView.registerCellClass(StakingDashboardActiveCell.self)
        rootView.collectionView.registerCellClass(StakingDashboardInactiveCell.self)
        rootView.collectionView.registerCellClass(StakingDashboardMoreOptionsCell.self)

        // rootView.collectionView.dataSource = self
        // rootView.collectionView.delegate = self

        rootView.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    @objc private func actionRefresh() {}
}

extension StakingDashboardViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        3
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {

    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {

    }
}

extension StakingDashboardViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {

    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {

    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
    }
}

extension StakingDashboardViewController: StakingDashboardViewProtocol {
    func didReceiveWallet(viewModel _: WalletSwitchViewModel) {
        // TODO: Add implementation with UI
    }

    func didReceiveStakings(viewModel: StakingDashboardViewModel) {
        // TODO: Add implementation with UI
    }
}

extension StakingDashboardViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
