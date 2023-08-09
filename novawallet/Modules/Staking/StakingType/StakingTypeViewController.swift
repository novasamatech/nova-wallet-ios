import UIKit
import SoraFoundation

final class StakingTypeViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingTypeViewLayout

    let presenter: StakingTypePresenterProtocol
    private var saveChangesAvailable: Bool = false

    init(
        presenter: StakingTypePresenterProtocol,
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
        view = StakingTypeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingTypeTitle(preferredLanguages: selectedLocale.rLanguages)
        navigationItem.rightBarButtonItem?.title = R.string.localizable.commonDone(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupNavigationItem() {
        let title = R.string.localizable.commonDone(preferredLanguages: selectedLocale.rLanguages)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: title,
            style: .done,
            target: self,
            action: #selector(doneAction)
        )
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    private func setupHandlers() {
        rootView.poolStakingBannerView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(poolBannerAction)
        ))
        rootView.directStakingBannerView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(directBannerAction)
        ))
    }

    @objc private func nominatorsAction() {
        didReceive(stakingTypeSelection: .direct)
        presenter.selectNominators()
    }

    @objc private func nominationPoolAction() {
        presenter.selectNominationPool()
    }

    @objc private func poolBannerAction() {
        presenter.change(stakingTypeSelection: .nominationPool)
    }

    @objc private func directBannerAction() {
        presenter.change(stakingTypeSelection: .direct)
    }

    @objc private func doneAction() {
        presenter.save()
    }
}

extension StakingTypeViewController: StakingTypeViewProtocol {
    func didReceivePoolBanner(viewModel: PoolStakingTypeViewModel) {
        rootView.bind(poolStakingTypeViewModel: viewModel)
        rootView.poolStakingBannerView.accountView.removeTarget(nil, action: nil, for: .allEvents)
        rootView.poolStakingBannerView.accountView.addTarget(
            self,
            action: #selector(nominationPoolAction),
            for: .touchUpInside
        )
    }

    func didReceiveDirectStakingBanner(viewModel: DirectStakingTypeViewModel, available: Bool) {
        rootView.bind(directStakingTypeViewModel: viewModel)
        rootView.directStakingBannerView.accountView.removeTarget(nil, action: nil, for: .allEvents)
        rootView.directStakingBannerView.accountView.addTarget(
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

    func didReceiveSaveChangesState(available: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = available
    }
}

extension StakingTypeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
