import UIKit

final class CustomNetworkViewLayout: ScrollableContainerLayoutView {
    let titleLabel: UILabel = .create { $0.apply(style: .boldTitle2Primary) }

    let networkTypeSwitch: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackgroundOnBlack()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let urlTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let urlInput: TextWithServiceInputView = .create { view in
        view.textField.returnKeyType = .done
        view.textField.keyboardType = .URL
    }

    let nameTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let nameInput: TextInputView = .create { view in
        view.textField.returnKeyType = .done
        view.textField.keyboardType = .asciiCapable
    }

    var currencySymbolTitleLabel: UILabel { currencyChainView.fView.valueTop }
    var currencySymbolInput: TextInputView { currencyChainView.fView.valueBottom }

    var chainIdTitleLabel: UILabel { currencyChainView.sView.valueTop }
    var chainIdInput: TextInputView { currencyChainView.sView.valueBottom }

    let blockExplorerUrlTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let blockExplorerUrlInput: TextWithServiceInputView = .create { view in
        view.textField.returnKeyType = .done
        view.textField.keyboardType = .URL
    }

    let coingeckoUrlTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let coingeckoUrlInput: TextWithServiceInputView = .create { view in
        view.textField.returnKeyType = .done
        view.textField.keyboardType = .URL
    }

    let currencyChainView: GenericPairValueView<
        GenericMultiValueView<TextInputView>,
        GenericMultiValueView<TextInputView>
    > = .create { view in
        view.makeHorizontal()
        view.stackView.distribution = .fillEqually
        view.spacing = Constants.stackSpacing

        view.fView.spacing = Constants.titleSpacing
        view.sView.spacing = Constants.titleSpacing

        view.fView.valueTop.textAlignment = .left
        view.sView.valueTop.textAlignment = .left

        view.fView.valueTop.apply(style: .footnoteSecondary)
        view.sView.valueTop.apply(style: .footnoteSecondary)

        view.fView.valueBottom.textField.returnKeyType = .done
        view.fView.valueBottom.textField.keyboardType = .asciiCapable

        view.sView.valueBottom.textField.returnKeyType = .done
        view.sView.valueBottom.textField.keyboardType = .numberPad
    }

    let actionLoadableView = LoadableActionView()
    var actionButton: TriangularedButton {
        actionLoadableView.actionButton
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.spacing = Constants.stackSpacing

        addArrangedSubview(titleLabel)

        networkTypeSwitch.snp.makeConstraints { make in
            make.height.equalTo(Constants.segmentControlHeight)
        }

        addArrangedSubview(networkTypeSwitch)

        addArrangedSubview(urlTitleLabel, spacingAfter: Constants.titleSpacing)
        addArrangedSubview(urlInput)

        addArrangedSubview(nameTitleLabel, spacingAfter: Constants.titleSpacing)
        addArrangedSubview(nameInput)

        addArrangedSubview(currencyChainView)

        addArrangedSubview(blockExplorerUrlTitleLabel, spacingAfter: Constants.titleSpacing)
        addArrangedSubview(blockExplorerUrlInput)

        addArrangedSubview(coingeckoUrlTitleLabel, spacingAfter: Constants.titleSpacing)
        addArrangedSubview(coingeckoUrlInput)

        addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    func hideNetworkTypeSwitch() {
        networkTypeSwitch.isHidden = true
    }

    func showNetworkTypeSwitch() {
        networkTypeSwitch.isHidden = false
    }

    func hideChainId() {
        currencyChainView.sView.isHidden = true
    }

    func showChainId() {
        currencyChainView.sView.isHidden = false
    }
}

// MARK: Private

private extension CustomNetworkViewLayout {
    func applyLocalization() {
        urlTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkAddRpcUrl()
        nameTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkAddName()
        currencySymbolTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkAddCurrencySymbol()
        chainIdTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkAddChainId()
        blockExplorerUrlTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkAddBlockExplorerUrl()
        coingeckoUrlTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkAddCoingeckoUrl()

        urlInput.locale = locale
        blockExplorerUrlInput.locale = locale
        coingeckoUrlInput.locale = locale
    }
}

// MARK: Constants

private extension CustomNetworkViewLayout {
    enum Constants {
        static let segmentControlHeight: CGFloat = 40
        static let stackSpacing: CGFloat = 16
        static let titleSpacing: CGFloat = 8
    }
}
