import UIKit

final class TokensManageAddViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleLabel: UILabel = .create {
        $0.numberOfLines = 0
        $0.apply(style: .secondaryScreenTitle)
    }

    let addressTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let addressInputView = TextInputView()

    let symbolTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let symbolInputView = TextInputView()

    let decimalsTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let decimalsInputView = TextInputView()

    let priceIdTitleLabel: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let priceIdInputView = TextInputView()

    let actionLoadableView = LoadableActionView()

    var actionButton: TriangularedButton {
        actionLoadableView.actionButton
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
        addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionLoadableView.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(16, after: titleLabel)

        containerView.stackView.addArrangedSubview(addressTitleLabel)
        containerView.stackView.setCustomSpacing(8, after: addressInputView)

        let symbolView = UIView.vStack(spacing: 8, [symbolTitleLabel, symbolInputView])
        let decimalsView = UIView.vStack(spacing: 8, [decimalsTitleLabel, decimalsInputView])
        let symbolAndDecimalView = UIView.hStack(spacing: 16, [symbolView, decimalsView])
        containerView.stackView.addArrangedSubview(symbolAndDecimalView)
        containerView.stackView.setCustomSpacing(16, after: symbolAndDecimalView)

        containerView.stackView.addArrangedSubview(priceIdTitleLabel)
        containerView.stackView.setCustomSpacing(8, after: priceIdTitleLabel)

        containerView.stackView.addArrangedSubview(priceIdInputView)
    }
}
