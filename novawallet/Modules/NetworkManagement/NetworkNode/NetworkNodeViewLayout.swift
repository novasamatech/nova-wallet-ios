import UIKit

final class NetworkNodeViewLayout: ScrollableContainerLayoutView {
    let titleLabel: UILabel = .create { $0.apply(style: .boldTitle2Primary) }
    let titleLabelFor: UILabel = .create { $0.apply(style: .boldTitle2Primary) }

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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleLabel, spacingAfter: 8)

        let container = UIView()
        container.addSubview(titleLabelFor)
        container.addSubview(chainView)

        titleLabelFor.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        chainView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabelFor.snp.trailing).offset(10)
            make.bottom.top.equalToSuperview()
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

// MARK: Model

extension NetworkNodeViewLayout {
    struct LoadingButtonViewModel {
        let title: String
        let enabled: Bool
        let loading: Bool
    }
}

// MARK: Private

private extension NetworkNodeViewLayout {
    func applyLocalization() {
        titleLabelFor.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonFor().lowercased()

        nameTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkInfoNodeName()
        urlTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.networkInfoNodeUrl()

        urlInput.locale = locale
    }
}
