import UIKit
import SoraFoundation

final class ParaStkYieldBoostScheduleConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = ParaStkYieldBoostScheduleConfirmViewLayout

    let presenter: ParaStkYieldBoostScheduleConfirmPresenterProtocol

    private var periodViewModel: UInt?
    private var thresholdViewModel: String?

    init(
        presenter: ParaStkYieldBoostScheduleConfirmPresenterProtocol,
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
        view = ParaStkYieldBoostScheduleConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonYieldBoost(preferredLanguages: languages)

        rootView.walletCell.titleLabel.text = R.string.localizable.commonWallet(preferredLanguages: languages)
        rootView.senderCell.titleLabel.text = R.string.localizable.commonSender(preferredLanguages: languages)

        rootView.networkFeeCell.rowContentView.locale = selectedLocale

        rootView.collatorCell.titleLabel.text = R.string.localizable.parachainStakingCollator(
            preferredLanguages: languages
        )

        rootView.stakingTypeCell.titleLabel.text = R.string.localizable.stakingTitle(
            preferredLanguages: languages
        )

        rootView.thresholdCell.titleLabel.text = R.string.localizable.yieldBoostThreshold(preferredLanguages: languages)

        rootView.periodCell.titleLabel.text = R.string.localizable.yieldBoostPeriodTitle(preferredLanguages: languages)

        applyPeriodViewModel()
        applyConfirmationViewModel()

        rootView.actionLoadableView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: languages
        )

        rootView.actionLoadableView.actionButton.invalidateLayout()
    }

    private func applyPeriodViewModel() {
        let title: String

        if let periodViewModel = periodViewModel {
            title = R.string.localizable.commonEveryDaysFormat(
                format: Int(bitPattern: periodViewModel),
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            title = ""
        }

        rootView.periodCell.bind(details: title)
    }

    private func applyConfirmationViewModel() {
        guard
            let periodViewModel = periodViewModel,
            let thresholdViewModel = thresholdViewModel else {
            return
        }
    }
}

extension ParaStkYieldBoostScheduleConfirmViewController: ParaStkYieldBoostScheduleConfirmViewProtocol {
    func didReceiveSender(viewModel: DisplayAddressViewModel) {
        rootView.senderCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveCollator(viewModel: DisplayAddressViewModel) {
        rootView.collatorCell.bind(viewModel: viewModel.cellViewModel)
    }

    func didReceiveWallet(viewModel: StackCellViewModel) {
        rootView.walletCell.bind(viewModel: viewModel)
    }

    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?) {
        rootView.networkFeeCell.rowContentView.bind(viewModel: viewModel)
    }

    func didReceiveThreshold(viewModel: String) {
        thresholdViewModel = viewModel

        rootView.thresholdCell.bind(details: viewModel)

        applyConfirmationViewModel()
    }

    func didReceivePeriod(viewModel: UInt) {
        periodViewModel = viewModel

        applyPeriodViewModel()
        applyConfirmationViewModel()
    }

    func didStartLoading() {
        rootView.actionLoadableView.startLoading()
    }

    func didStopLoading() {
        rootView.actionLoadableView.stopLoading()
    }
}

extension ParaStkYieldBoostScheduleConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
