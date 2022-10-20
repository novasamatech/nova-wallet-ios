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

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.amountInputView.addTarget(
            self,
            action: #selector(actionAmountChange),
            for: .editingChanged
        )

        rootView.nayButton.addTarget(
            self,
            action: #selector(actionVoteNay),
            for: .touchUpInside
        )

        rootView.ayeButton.addTarget(
            self,
            action: #selector(actionVoteAye),
            for: .touchUpInside
        )

        rootView.convictionView.slider.addTarget(
            self,
            action: #selector(actionConvictionChanged),
            for: .valueChanged
        )
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

        rootView.nayButton.imageWithTitleView?.title = R.string.localizable.governanceNay(preferredLanguages: languages)
        rootView.ayeButton.imageWithTitleView?.title = R.string.localizable.governanceAye(preferredLanguages: languages)

        setupAmountInputAccessoryView(for: selectedLocale)
    }

    private func applyReferendumNumber() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.govVoteSetupTitleFormat(
            referendumNumber ?? "",
            preferredLanguages: languages
        )
    }

    private func setupAmountInputAccessoryView(for locale: Locale) {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: locale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    @objc private func actionVoteNay() {
        presenter.proceedNay()
    }

    @objc private func actionVoteAye() {
        presenter.proceedAye()
    }

    @objc private func actionConvictionChanged() {
        presenter.selectConvictionValue(rootView.convictionView.slider.value)
    }

    @objc func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)
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

    func didReceiveAmountInputPrice(viewModel: String?) {
        rootView.amountInputView.bind(priceViewModel: viewModel)
    }

    func didReceiveVotes(viewModel: String) {
        rootView.convictionView.bind(votes: viewModel)
    }

    func didReceiveConviction(viewModel: UInt) {
        if viewModel < rootView.convictionView.slider.numberOfValues {
            rootView.convictionView.slider.value = viewModel
        }
    }

    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel) {
        rootView.bindLockAmount(viewModel: viewModel)
    }

    func didReceiveLockedPeriod(viewModel: ReferendumLockTransitionViewModel) {
        rootView.bindLockPeriod(viewModel: viewModel)
    }
}

extension ReferendumVoteSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension ReferendumVoteSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
