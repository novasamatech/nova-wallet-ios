import UIKit

final class NetworkAddNodeViewLayout: ScrollableContainerLayoutView {
    let titleLabel: UILabel = .create { $0.apply(style: .boldTitle2Primary) }
    
    let chainView = AssetListChainView()
    
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
        setupTextFields()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()
        
        addArrangedSubview(titleLabel, spacingAfter: 8)
        
        let container = UIView()
        container.addSubview(chainView)
        chainView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        
        addArrangedSubview(container, spacingAfter: 16)

        addArrangedSubview(urlTitleLabel, spacingAfter: 8)
        addArrangedSubview(urlInput, spacingAfter: 16)

        addArrangedSubview(nameTitleLabel, spacingAfter: 8)
        addArrangedSubview(nameInput)
        
        addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

// MARK: Private

private extension NetworkAddNodeViewLayout {
    func applyLocalization() {
        titleLabel.text = R.string.localizable.networkNodeAddTitle(preferredLanguages: locale.rLanguages)
        
        nameTitleLabel.text = R.string.localizable.networkInfoName(preferredLanguages: locale.rLanguages)
        urlTitleLabel.text = R.string.localizable.networkInfoNodeUrl(preferredLanguages: locale.rLanguages)

        urlInput.locale = locale
    }

    private func setupTextFields() {}
}
