import UIKit
import SoraFoundation
import CommonWallet

final class ReferendumVoteSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumVoteSetupViewLayout

    let presenter: ReferendumVoteSetupPresenterProtocol

    private var referendumNumber: String?

    init(
        presenter: ReferendumVoteSetupPresenterProtocol,
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
        view = ReferendumVoteSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        applyReferendumNumber()

        rootView.amountView.titleView.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: languages
        )

        rootView.amountView.detailsTitleLabel.text = R.string.localizable.commonAvailablePrefix(
            preferredLanguages: languages
        )

        rootView.convictionView.titleLabel.text = R.string.localizable.govVoteConvictionTitle(
            preferredLanguages: languages
        )

        rootView.lockAmountTitleLabel.text = R.string.localizable.commonGovLock(preferredLanguages: languages)
        rootView.lockPeriodTitleLabel.text = R.string.localizable.commonLockingPeriod(preferredLanguages: languages)

        rootView.feeView.locale = selectedLocale

        let hint = R.string.localizable.govVoteSetupHint(preferredLanguages: languages)
        rootView.hintListView.bind(texts: [hint])

        rootView.nayButton.imageWithTitleView?.title = R.string.localizable.governanceNay(preferredLanguages: languages)
        rootView.ayeButton.imageWithTitleView?.title = R.string.localizable.governanceAye(preferredLanguages: languages)
    }

    private func applyReferendumNumber() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.govVoteSetupTitleFormat(
            referendumNumber ?? "",
            preferredLanguages: languages
        )
    }
}

extension ReferendumVoteSetupViewController: ReferendumVoteSetupViewProtocol {
    func didReceive(referendumNumber: String) {
        self.referendumNumber = referendumNumber

        applyReferendumNumber()
    }

    func didReceiveBalance(viewModel: String) {
        rootView.amountView.detailsValueLabel.text = viewModel
    }

    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel) {
        rootView.amountInputView.bind(assetViewModel: viewModel.assetViewModel)
    }

    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.feeView.bind(viewModel: viewModel)
    }

    func didReceiveAmountInputPrice(viewModel: String?) {
        rootView.amountInputView.bind(priceViewModel: viewModel)
    }
}

extension ReferendumVoteSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
