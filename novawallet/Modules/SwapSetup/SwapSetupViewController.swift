import UIKit

final class SwapSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapSetupViewLayout

    let presenter: SwapSetupPresenterProtocol

    init(presenter: SwapSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.payAmountInputView.symbolHubMultiValueView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(selectPayTokenAction)
            ))
        rootView.receiveAmountInputView.symbolHubMultiValueView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(selectReceiveTokenAction)
            ))
    }

    private func emptyPayViewModel() -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: "Pay",
            subtitle: "Select a token"
        )
    }

    private func emptyReceiveViewModel() -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: "Receive",
            subtitle: "Select a token"
        )
    }

    @objc private func selectPayTokenAction() {
        presenter.selectPayToken()
    }

    @objc private func selectReceiveTokenAction() {
        presenter.selectReceiveToken()
    }
}

extension SwapSetupViewController: SwapSetupViewProtocol {
    func didReceiveButtonState(title: String, enabled: Bool) {
        rootView.actionButton.applyState(title: title, enabled: enabled)
    }

    func didReceiveInputChainAsset(payViewModel viewModel: SwapsAssetViewModel?) {
        if let viewModel = viewModel {
            rootView.payAmountInputView.bind(assetViewModel: viewModel)
        } else {
            rootView.payAmountInputView.bind(emptyViewModel: emptyPayViewModel())
        }
    }

    func didReceiveAmount(payInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        rootView.payAmountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(payViewModel viewModel: String?) {
        rootView.payAmountInputView.bind(priceViewModel: viewModel)
    }

    func didReceiveInputChainAsset(receiveViewModel viewModel: SwapsAssetViewModel?) {
        if let viewModel = viewModel {
            rootView.receiveAmountInputView.bind(assetViewModel: viewModel)
        } else {
            rootView.receiveAmountInputView.bind(emptyViewModel: emptyReceiveViewModel())
        }
    }

    func didReceiveAmount(receiveInputViewModel inputViewModel: AmountInputViewModelProtocol) {
        rootView.receiveAmountInputView.bind(inputViewModel: inputViewModel)
    }

    func didReceiveAmountInputPrice(receiveViewModel viewModel: String?) {
        rootView.receiveAmountInputView.bind(priceViewModel: viewModel)
    }
}
