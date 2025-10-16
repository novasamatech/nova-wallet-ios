import UIKit
import Foundation_iOS

class BaseReferendumVoteSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = BaseReferendumVoteSetupViewLayout

    private let presenter: BaseReferendumVoteSetupPresenterProtocol

    init(
        presenter: BaseReferendumVoteSetupPresenterProtocol,
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

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    func setupHandlers() {
        rootView.amountInputView.addTarget(
            self,
            action: #selector(actionAmountChange),
            for: .editingChanged
        )

        rootView.convictionView.slider.addTarget(
            self,
            action: #selector(actionConvictionChanged),
            for: .valueChanged
        )
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.amountView.titleView.text = R.string(
            preferredLanguages: languages
        ).localizable.walletSendAmountTitle()

        rootView.amountView.detailsTitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.commonAvailablePrefix()

        rootView.convictionView.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.govVoteConvictionTitle()

        rootView.convictionHintView.iconDetailsView.detailsLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.govVoteConvictionHintTitle()

        rootView.lockAmountTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonGovLock()
        rootView.lockPeriodTitleLabel.text = R.string(preferredLanguages: languages).localizable.commonLockingPeriod()

        setupAmountInputAccessoryView(for: selectedLocale)
    }

    private func setupAmountInputAccessoryView(for locale: Locale) {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: locale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
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

extension BaseReferendumVoteSetupViewController: BaseReferendumVoteSetupViewProtocol {
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

    func didReceiveLockedPeriod(viewModel: ReferendumLockTransitionViewModel) {
        rootView.lockedPeriodView.bind(viewModel: viewModel)
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
}

extension BaseReferendumVoteSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension BaseReferendumVoteSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension BaseReferendumVoteSetupViewController: ImportantViewProtocol {}
