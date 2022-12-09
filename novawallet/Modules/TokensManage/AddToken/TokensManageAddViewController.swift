import UIKit
import SoraFoundation

final class TokensManageAddViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageAddViewLayout

    let presenter: TokensManageAddPresenterProtocol

    init(presenter: TokensManageAddPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokensManageAddViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionAdd),
            for: .touchUpInside
        )

        rootView.addressInputView.addTarget(
            self,
            action: #selector(actionContractAddressChanged),
            for: .editingChanged
        )

        rootView.symbolInputView.addTarget(
            self,
            action: #selector(actionSymbolChanged),
            for: .editingChanged
        )

        rootView.decimalsInputView.addTarget(
            self,
            action: #selector(actionDecimalsChanged),
            for: .editingChanged
        )

        rootView.priceIdInputView.addTarget(
            self,
            action: #selector(actionPriceIdChanged),
            for: .editingChanged
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string.localizable.addTokenTitle(preferredLanguages: languages)
        rootView.symbolTitleLabel.text = R.string.localizable.commonTokenSymbol(preferredLanguages: languages)
        rootView.decimalsTitleLabel.text = R.string.localizable.commonTokenDecimals(preferredLanguages: languages)
        rootView.priceIdTitleLabel.text = R.string.localizable.addTokenPriceTitle(preferredLanguages: languages)

        updateActionButton()
    }

    private func updateActionButton() {
        let languages = selectedLocale.rLanguages

        if !rootView.addressInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.addTokenEnterContractAddress(
                preferredLanguages: languages
            )

            return
        }

        if !rootView.symbolInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.addTokenEnterSymbol(
                preferredLanguages: languages
            )

            return
        }

        if !rootView.decimalsInputView.completed {
            rootView.actionButton.applyDisabledStyle()
            rootView.actionButton.isUserInteractionEnabled = false

            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.addTokenEnterDecimals(
                preferredLanguages: languages
            )

            return
        }

        rootView.actionButton.applyEnabledStyle()
        rootView.actionButton.isUserInteractionEnabled = true

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.addTokenAction(
            preferredLanguages: languages
        )
    }

    @objc func actionAdd() {
        presenter.confirmTokenAdd()
    }

    @objc func actionContractAddressChanged() {
        let partialAddress = rootView.addressInputView.textField.text ?? ""
        presenter.handlePartial(address: partialAddress)
    }

    @objc func actionSymbolChanged() {
        let partialSymbol = rootView.symbolInputView.textField.text ?? ""
        presenter.handlePartial(symbol: partialSymbol)
    }

    @objc func actionDecimalsChanged() {
        let partialDecimals = rootView.decimalsInputView.textField.text ?? ""
        presenter.handlePartial(decimals: partialDecimals)
    }

    @objc func actionPriceIdChanged() {
        let partialPriceId = rootView.priceIdInputView.textField.text ?? ""
        presenter.handlePartial(priceId: partialPriceId)
    }
}

extension TokensManageAddViewController: TokensManageAddViewProtocol {
    func didReceiveAddress(viewModel: InputViewModelProtocol) {
        rootView.addressInputView.bind(inputViewModel: viewModel)
    }

    func didReceiveSymbol(viewModel: InputViewModelProtocol) {
        rootView.symbolInputView.bind(inputViewModel: viewModel)
    }

    func didReceiveDecimals(viewModel: InputViewModelProtocol) {
        rootView.decimalsInputView.bind(inputViewModel: viewModel)
    }

    func didReceivePriceId(viewModel: InputViewModelProtocol) {
        rootView.priceIdInputView.bind(inputViewModel: viewModel)
    }
}

extension TokensManageAddViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
