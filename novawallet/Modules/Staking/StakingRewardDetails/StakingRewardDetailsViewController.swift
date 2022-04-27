import UIKit
import SoraFoundation

final class StakingRewardDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingRewardDetailsViewLayout

    let presenter: StakingRewardDetailsPresenterProtocol

    init(
        presenter: StakingRewardDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
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
        view = StakingRewardDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(handlePayoutButtonAction),
            for: .touchUpInside
        )

        rootView.validatorCell.addTarget(
            self,
            action: #selector(handleAccountAction),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.stakingRewardDetailsTitle(preferredLanguages: selectedLocale.rLanguages)

        let title = R.string.localizable.stakingRewardDetailsPayout(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.validatorCell.titleLabel.text = R.string.localizable.stakingCommonValidator(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.eraCell.titleLabel.text = R.string.localizable.stakingCommonEra(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.actionButton.imageWithTitleView?.title = title
    }

    @objc private func handlePayoutButtonAction() {
        presenter.handlePayoutAction()
    }

    @objc private func handleAccountAction() {
        presenter.handleValidatorAccountAction()
    }
}

extension StakingRewardDetailsViewController: StakingRewardDetailsViewProtocol {
    func didReceive(amountViewModel: BalanceViewModelProtocol) {
        rootView.amountView.bind(viewModel: amountViewModel)
    }

    func didReceive(validatorViewModel: StackCellViewModel) {
        rootView.validatorCell.bind(viewModel: validatorViewModel)
    }

    func didReceive(eraViewModel: StackCellViewModel) {
        rootView.eraCell.bind(viewModel: eraViewModel)
    }
}

extension StakingRewardDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
