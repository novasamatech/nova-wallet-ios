import UIKit

final class DAppAddFavoriteViewLayout: UIView {
    enum Constants {
        static let iconViewSize = CGSize(width: 88.0, height: 88.0)
        static let iconContentInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
        static var iconDisplaySize: CGSize {
            CGSize(
                width: iconViewSize.width - iconContentInsets.left - iconContentInsets.right,
                height: iconViewSize.height - iconContentInsets.top - iconContentInsets.bottom
            )
        }
    }

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let saveButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        button.tintColor = R.color.colorNovaBlue()!

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.regularBody
        ]

        button.setTitleTextAttributes(attributes, for: .normal)
        button.setTitleTextAttributes(attributes, for: .highlighted)
        button.setTitleTextAttributes(attributes, for: .disabled)

        return button
    }()

    let iconView: DAppIconView = {
        let view = DAppIconView()
        view.backgroundView.cornerRadius = 22.0
        view.contentInsets = Constants.iconContentInsets
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    let titleInputView: TextInputField = {
        let view = TextInputField()
        return view
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    let addressInputView: TextInputField = {
        let view = TextInputField()
        view.textField.keyboardType = .URL
        view.textField.autocorrectionType = .no
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let iconContentView = UIView()
        containerView.stackView.addArrangedSubview(iconContentView)

        iconContentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.size.equalTo(Constants.iconViewSize)
        }

        containerView.stackView.setCustomSpacing(16.0, after: iconContentView)

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(titleInputView)
        titleInputView.snp.makeConstraints { make in
            make.height.equalTo(48.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: titleInputView)

        containerView.stackView.addArrangedSubview(addressLabel)
        containerView.stackView.setCustomSpacing(8.0, after: addressLabel)

        containerView.stackView.addArrangedSubview(addressInputView)
        addressInputView.snp.makeConstraints { make in
            make.height.equalTo(48.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: addressInputView)
    }
}
