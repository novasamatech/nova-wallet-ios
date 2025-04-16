import UIKit
import Foundation_iOS

final class GovernanceDelegateSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceDelegateSetupViewLayout

    let presenter: GovernanceDelegateSetupPresenterProtocol

    private let delegateTitle: LocalizableResource<String>

    init(
        presenter: GovernanceDelegateSetupPresenterProtocol,
        delegateTitle: LocalizableResource<String>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.delegateTitle = delegateTitle
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceDelegateSetupViewLayout()
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

        rootView.proceedButton.addTarget(
            self,
            action: #selector(actionProceed),
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

        title = delegateTitle.value(for: selectedLocale)

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
        rootView.undelegatingPeriodTitleLabel.text = R.string.localizable.govUndelegatingPeriod(
            preferredLanguages: languages
        )

        rootView.proceedButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )

        setupAmountInputAccessoryView(for: selectedLocale)
    }

    private func setupAmountInputAccessoryView(for locale: Locale) {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: locale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    @objc private func actionProceed() {
        presenter.proceed()
    }

    @objc private func actionConvictionChanged() {
        presenter.selectConvictionValue(rootView.convictionView.slider.value)
    }

    @objc func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)
    }

    @objc func actionReuseGovernanceLock() {
        presenter.reuseGovernanceLock()
    }

    @objc func actionReuseAllLock() {
        presenter.reuseAllLock()
    }
}

extension GovernanceDelegateSetupViewController: GovernanceDelegateSetupViewProtocol {
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
        rootView.lockedAmountView.bind(viewModel: viewModel)
    }

    func didReceiveUndelegatingPeriod(viewModel: String) {
        rootView.undelegatingPeriodView.valueLabel.text = viewModel
    }

    func didReceiveLockReuse(viewModel: ReferendumLockReuseViewModel) {
        rootView.bindReuseLocks(viewModel: viewModel, locale: selectedLocale)

        rootView.govLocksReuseButton?.addTarget(
            self,
            action: #selector(actionReuseGovernanceLock),
            for: .touchUpInside
        )

        rootView.allLocksReuseButton?.addTarget(
            self,
            action: #selector(actionReuseAllLock),
            for: .touchUpInside
        )
    }

    func didReceiveHints(viewModel: [String]) {
        rootView.hintView.bind(texts: viewModel)
    }
}

extension GovernanceDelegateSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension GovernanceDelegateSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension GovernanceDelegateSetupViewController: ImportantViewProtocol {}
