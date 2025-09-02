import UIKit
import Foundation_iOS

final class CardTopUpTransferSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let title: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
    }

    let recepientTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        return label
    }()

    let recepientInputView: AccountInputView = .create { view in
        view.scanButton.isHidden = true
        view.clearButton.removeFromSuperview()
        view.isUserInteractionEnabled = false
        view.localizablePlaceholder = LocalizableResource { locale in
            R.string.localizable.transferSetupRecipientInputPlaceholder(preferredLanguages: locale.rLanguages)
        }
    }

    let originFeeView: NetworkFeeInfoView = .create { view in
        view.hideInfoIcon()
    }

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView: NewAmountInputView = .create { view in
        view.isUserInteractionEnabled = false
    }

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
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(title)
        title.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
        }

        containerView.stackView.setCustomSpacing(16.0, after: title)

        containerView.stackView.addArrangedSubview(recepientTitleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: recepientTitleLabel)
        containerView.stackView.addArrangedSubview(recepientInputView)
        containerView.stackView.setCustomSpacing(40.0, after: recepientInputView)

        containerView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        containerView.stackView.setCustomSpacing(16.0, after: amountInputView)

        containerView.stackView.addArrangedSubview(originFeeView)
    }
}
