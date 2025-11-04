import Foundation
import UIKit
import Foundation_iOS

final class GiftTransferSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = GiftTransferSetupViewLayout

    let presenter: GiftTransferSetupPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    var issues: [GiftSetupViewIssue] = []

    var chainAsset: ChainAssetViewModel?

    init(
        presenter: GiftTransferSetupPresenterProtocol,
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
        view = GiftTransferSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }
}

// MARK: - Private

private extension GiftTransferSetupViewController {
    func setupHandlers() {
        rootView.amountInputView.addTarget(
            self,
            action: #selector(actionAmountChange),
            for: .editingChanged
        )
        rootView.genericActionView.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )
        rootView.getTokenButton.addTarget(
            self,
            action: #selector(actionGetTokens),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        let localizedStrings = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable

        rootView.genericActionView.imageWithTitleView?.title = localizedStrings.commonContinue()

        rootView.amountView.titleView.text = localizedStrings.walletSendAmountTitle()

        rootView.feeView.titleButton.imageWithTitleView?.title = localizedStrings.commonNetworkFee()

        updateActionButtonState()

        setupAmountInputAccessoryView(for: selectedLocale)

        guard let chainAsset else { return }

        rootView.getTokenButton.imageWithTitleView?.title = localizedStrings.swapsSetupDepositButtonTitle(
            chainAsset.assetViewModel.symbol
        )
    }

    func setupAmountInputAccessoryView(for locale: Locale) {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: locale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    func updateActionButtonState() {
        guard issues.isEmpty else {
            rootView.genericActionView.applyDisabledStyle()
            rootView.genericActionView.isUserInteractionEnabled = false

            rootView.genericActionView.imageWithTitleView?.title = issues.last?.actionText
            rootView.genericActionView.invalidateLayout()

            return
        }

        guard rootView.amountInputView.completed else {
            rootView.genericActionView.applyDisabledStyle()
            rootView.genericActionView.isUserInteractionEnabled = false

            rootView.genericActionView.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.transferSetupEnterAmount()
            rootView.genericActionView.invalidateLayout()

            return
        }

        rootView.genericActionView.applyEnabledStyle()
        rootView.genericActionView.isUserInteractionEnabled = true

        rootView.genericActionView.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()
        rootView.genericActionView.invalidateLayout()
    }

    @objc func actionAmountChange() {
        let amount = rootView.amountInputView.inputViewModel?.decimalAmount
        presenter.updateAmount(amount)

        updateActionButtonState()
    }

    @objc func actionProceed() {
        presenter.proceed()
    }

    @objc func actionGetTokens() {
        presenter.getTokens()
    }
}

// MARK: - GiftTransferSetupViewProtocol

extension GiftTransferSetupViewController: GiftTransferSetupViewProtocol {
    func didReceiveTransferableBalance(viewModel: String) {
        rootView.amountView.detailsTitleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonTransferablePrefix()

        rootView.amountView.detailsValueLabel.text = viewModel
    }

    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel) {
        chainAsset = viewModel
        rootView.amountInputView.bind(assetViewModel: viewModel.assetViewModel)
        setupLocalization()
    }

    func didReceiveFee(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>) {
        rootView.feeView.bind(loadableViewModel: viewModel)
    }

    func didReceiveAmount(inputViewModel: any AmountInputViewModelProtocol) {
        rootView.amountInputView.bind(inputViewModel: inputViewModel)

        updateActionButtonState()
    }

    func didReceiveAmountInputPrice(viewModel: String?) {
        rootView.amountInputView.bind(priceViewModel: viewModel)
    }

    func didReceive(issues: [GiftSetupViewIssue]) {
        self.issues = issues

        rootView.hideIssues()

        issues.forEach { issue in
            switch issue {
            case let .insufficientBalance(attributes):
                rootView.displayIssue(with: attributes)
            case let .minAmountViolation(attributes):
                rootView.displayIssue(with: attributes)
            }
        }
    }

    func didReceive(title: GiftSetupNetworkContainerViewModel) {
        rootView.networkContainerView.bind(viewModel: title)
    }
}

// MARK: - AmountInputAccessoryViewDelegate

extension GiftTransferSetupViewController: AmountInputAccessoryViewDelegate {
    func didSelect(
        on _: AmountInputAccessoryView,
        percentage: Float
    ) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

// MARK: - KeyboardAdoptable

extension GiftTransferSetupViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if rootView.amountInputView.textField.isFirstResponder {
                targetView = rootView.amountInputView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

// MARK: - Localizable

extension GiftTransferSetupViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
