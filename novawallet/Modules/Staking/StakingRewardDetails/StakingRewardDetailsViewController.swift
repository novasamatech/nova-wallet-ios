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

        setupTopTitle()
        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupTopTitle() {
        navigationItem.titleView = rootView.titleLabel
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
        rootView.validatorCell.titleLabel.text = R.string.localizable.stakingCommonValidator(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.eraCell.titleLabel.text = R.string.localizable.stakingCommonEra(
            preferredLanguages: selectedLocale.rLanguages
        )

        let actionTitle = R.string.localizable.stakingRewardDetailsPayout(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.actionButton.imageWithTitleView?.title = actionTitle
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

    func didReceive(remainedTime: NSAttributedString) {
        rootView.titleLabel.attributedText = remainedTime
        rootView.titleLabel.sizeToFit()
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
