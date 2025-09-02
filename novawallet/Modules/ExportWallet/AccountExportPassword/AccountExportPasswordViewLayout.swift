import UIKit
import UIKit_iOS

final class AccountExportPasswordViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .fill
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(
            top: UIConstants.verticalTitleInset,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let enterPasswordView: PasswordInputView = .create { view in
        view.textField.returnKeyType = .next
    }

    let confirmPasswordView: PasswordInputView = .create { view in
        view.textField.returnKeyType = .done
    }

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(proceedButton.snp.top).offset(-16.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(subtitleLabel)
        containerView.stackView.setCustomSpacing(24.0, after: subtitleLabel)

        containerView.stackView.addArrangedSubview(enterPasswordView)
        enterPasswordView.snp.makeConstraints { make in
            make.height.equalTo(48)
        }

        containerView.stackView.setCustomSpacing(16.0, after: enterPasswordView)

        containerView.stackView.addArrangedSubview(confirmPasswordView)
        confirmPasswordView.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
    }
}
