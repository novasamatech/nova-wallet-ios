import UIKit
import SoraFoundation

final class SwapSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapSetupViewLayout

    let presenter: SwapSetupPresenterProtocol

    init(
        presenter: SwapSetupPresenterProtocol,
        localizationManager: LocalizationManager
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
        view = SwapSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.payAmountInputView.assetControl.addTarget(
            self,
            action: #selector(selectPayTokenAction),
            for: .touchUpInside
        )
        rootView.receiveAmountInputView.assetControl.addTarget(
            self,
            action: #selector(selectReceiveTokenAction),
            for: .touchUpInside
        )
        rootView.actionButton.addTarget(
            self,
            action: #selector(continueAction),
            for: .touchUpInside
        )
        rootView.switchButton.addTarget(
            self,
            action: #selector(swapAction),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.walletAssetsSwap(preferredLanguages: selectedLocale.rLanguages)
        rootView.setup(locale: selectedLocale)
    }

    @objc private func selectPayTokenAction() {
        rootView.receiveAmountInputView.endEditing(true)
        presenter.selectPayToken()
    }

    @objc private func selectReceiveTokenAction() {
        rootView.payAmountInputView.endEditing(true)
        presenter.selectReceiveToken()
    }

    @objc private func continueAction() {
        presenter.proceed()
    }

    @objc private func swapAction() {
        presenter.swap()
    }
}

extension SwapSetupViewController: SwapSetupViewProtocol {
    func didReceiveButtonState(title: String, enabled: Bool) {
        rootView.actionButton.applyState(title: title, enabled: enabled)
    }

    func didReceiveTitle(payViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        rootView.payAmountView.bind(model: viewModel)
    }

    func didReceiveInputChainAsset(payViewModel viewModel: SwapAssetInputViewModel) {
        switch viewModel {
        case let .asset(assetViewModel):
            rootView.payAmountInputView.bind(assetViewModel: assetViewModel)
        case let .empty(emptySwapsAssetViewModel):
            rootView.payAmountInputView.bind(emptyViewModel: emptySwapsAssetViewModel)
        }
    }

    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        rootView.payAmountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(payViewModel viewModel: String?) {
        rootView.payAmountInputView.bind(priceViewModel: viewModel)
    }

    func didReceiveTitle(receiveViewModel viewModel: TitleHorizontalMultiValueView.Model) {
        rootView.receiveAmountView.bind(model: viewModel)
    }

    func didReceiveInputChainAsset(receiveViewModel viewModel: SwapAssetInputViewModel) {
        switch viewModel {
        case let .asset(swapsAssetViewModel):
            rootView.receiveAmountInputView.bind(assetViewModel: swapsAssetViewModel)
        case let .empty(emptySwapsAssetViewModel):
            rootView.receiveAmountInputView.bind(emptyViewModel: emptySwapsAssetViewModel)
        }
    }

    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        rootView.receiveAmountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(receiveViewModel viewModel: String?) {
        rootView.receiveAmountInputView.bind(priceViewModel: viewModel)
    }

    func didReceiveRate(viewModel: LoadableViewModelState<BalanceViewModelProtocol>) {
        rootView.rateCell.bind(loadableViewModel: viewModel)
    }

    func didReceiveNetworkFee(viewModel: LoadableViewModelState<BalanceViewModelProtocol>) {
        rootView.networkFeeCell.bind(loadableViewModel: viewModel)
    }
}

extension SwapSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
