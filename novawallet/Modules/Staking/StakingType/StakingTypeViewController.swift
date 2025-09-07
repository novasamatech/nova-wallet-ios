import UIKit
import Foundation_iOS

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
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingTypeTitle()
        navigationItem.rightBarButtonItem?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonDone()
    }

    private func setupNavigationItem() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonDone()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: title,
            style: .plain,
            target: self,
            action: #selector(doneAction)
        )
        navigationItem.rightBarButtonItem?.tintColor = R.color.colorButtonTextAccent()
        navigationItem.rightBarButtonItem?.isEnabled = false

        let backBarButtonItem = UIBarButtonItem(
            image: R.image.iconBack()!,
            style: .plain,
            target: self,
            action: #selector(backAction)
        )
        backBarButtonItem.imageInsets = .init(top: 0, left: -8, bottom: 0, right: 0)
        navigationItem.leftBarButtonItem = backBarButtonItem
    }

    private func setupHandlers() {
        let directStakingTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(directBannerAction)
        )
        directStakingTapGesture.delegate = self
        rootView.directStakingBannerView.addGestureRecognizer(directStakingTapGesture)

        let poolStakingTapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(poolBannerAction)
        )
        poolStakingTapGesture.delegate = self
        rootView.poolStakingBannerView.addGestureRecognizer(poolStakingTapGesture)

        rootView.poolStakingBannerView.accountView.addTarget(
            self,
            action: #selector(nominationPoolAction),
            for: .touchUpInside
        )
        rootView.directStakingBannerView.accountView.addTarget(
            self,
            action: #selector(validatorsAction),
            for: .touchUpInside
        )
    }

    @objc private func validatorsAction() {
        presenter.selectValidators()
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

    @objc private func backAction() {
        presenter.back()
    }

    private func updateBannerSelection<T1, T2>(
        activeBanner: StakingTypeBannerView<T1>,
        inactiveBanner: StakingTypeBannerView<T2>
    ) {
        activeBanner.borderView.isHighlighted = true
        activeBanner.radioSelectorView.selected = true
        activeBanner.accountView.isHidden = false

        inactiveBanner.borderView.isHighlighted = false
        inactiveBanner.radioSelectorView.selected = false
        inactiveBanner.accountView.isHidden = true
    }
}

extension StakingTypeViewController: StakingTypeViewProtocol {
    func didReceivePoolBanner(viewModel: PoolStakingTypeViewModel, available: Bool) {
        rootView.bind(poolStakingTypeViewModel: viewModel)
        rootView.poolStakingBannerView.setEnabledStyle(available)
    }

    func didReceiveDirectStakingBanner(viewModel: DirectStakingTypeViewModel, available: Bool) {
        rootView.bind(directStakingTypeViewModel: viewModel)
        rootView.directStakingBannerView.setEnabledStyle(available)
    }

    func didReceive(stakingTypeSelection: StakingTypeSelection) {
        switch stakingTypeSelection {
        case .direct:
            updateBannerSelection(
                activeBanner: rootView.directStakingBannerView,
                inactiveBanner: rootView.poolStakingBannerView
            )
        case .nominationPool:
            updateBannerSelection(
                activeBanner: rootView.poolStakingBannerView,
                inactiveBanner: rootView.directStakingBannerView
            )
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

extension StakingTypeViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
    }
}
