import UIKit

final class StakingTypeViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingTypeViewLayout

    let presenter: StakingTypePresenterProtocol

    init(presenter: StakingTypePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingTypeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.poolStakingBannerView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(didTapOnPoolBanner)
        ))
        rootView.directStakingBannerView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(didTapOnDirectBanner)
        ))
    }

    @objc private func nominatorsAction() {
        didReceive(stakingTypeSelection: .direct)
        presenter.selectNominators()
    }

    @objc private func nominationPoolAction() {
        presenter.selectNominationPool()
    }

    @objc private func didTapOnPoolBanner() {
        presenter.change(stakingTypeSelection: .nominationPool)
    }

    @objc private func didTapOnDirectBanner() {
        presenter.change(stakingTypeSelection: .direct)
    }
}

extension StakingTypeViewController: StakingTypeViewProtocol {
    func didReceivePoolBanner(viewModel: PoolStakingTypeViewModel) {
        rootView.bind(poolStakingTypeViewModel: viewModel)
        rootView.poolStakingBannerView.accountView?.removeTarget(nil, action: nil, for: .allEvents)
        rootView.poolStakingBannerView.accountView?.addTarget(
            self,
            action: #selector(nominationPoolAction),
            for: .touchUpInside
        )
    }

    func didReceiveDirectStakingBanner(viewModel: DirectStakingTypeViewModel, available: Bool) {
        rootView.bind(directStakingTypeViewModel: viewModel)
        rootView.directStakingBannerView.accountView?.removeTarget(nil, action: nil, for: .allEvents)
        rootView.directStakingBannerView.accountView?.addTarget(
            self,
            action: #selector(nominatorsAction),
            for: .touchUpInside
        )
        if !available {
            rootView.directStakingBannerView.alpha = 0.5
        } else {
            rootView.directStakingBannerView.alpha = 1
        }
    }

    func didReceive(stakingTypeSelection: StakingTypeSelection) {
        switch stakingTypeSelection {
        case .direct:
            rootView.poolStakingBannerView.backgroundView.isHighlighted = false
            rootView.poolStakingBannerView.radioSelectorView.selected = false
            rootView.directStakingBannerView.backgroundView.isHighlighted = true
            rootView.directStakingBannerView.radioSelectorView.selected = true
        case .nominationPool:
            rootView.directStakingBannerView.backgroundView.isHighlighted = false
            rootView.directStakingBannerView.radioSelectorView.selected = false
            rootView.poolStakingBannerView.backgroundView.isHighlighted = true
            rootView.poolStakingBannerView.radioSelectorView.selected = true
        }
    }
}
