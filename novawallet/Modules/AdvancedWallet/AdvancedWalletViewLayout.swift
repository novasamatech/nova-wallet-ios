import UIKit
import SoraUI

final class AdvancedWalletViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .fill
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(
            top: 8.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
        view.stackView.spacing = 16.0
        return view
    }()

    let substrateCryptoTypeView: BorderedSubtitleActionView = UIFactory.default.createBorderSubtitleActionView()

    let substrateBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let substrateTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let substrateTextField: UITextField = {
        let view = UITextField()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.tintColor = R.color.colorWhite()
        return view
    }()

    let ethereumCryptoTypeView: BorderedSubtitleActionView = UIFactory.default.createBorderSubtitleActionView()

    let ethereumBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()
    let ethereumTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let ethereumTextField: UITextField = {
        let view = UITextField()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.tintColor = R.color.colorWhite()
        return view
    }()

    private(set) var applyButton: TriangularedButton?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupApplyButton() {
        guard applyButton == nil else {
            return
        }

        let button = TriangularedButton()
        button.applyDefaultStyle()
        applyButton = button

        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        containerView.scrollBottomOffset = UIConstants.actionBottomInset + UIConstants.actionHeight + 16.0
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }

        containerView.stackView.addArrangedSubview(substrateCryptoTypeView)
        containerView.stackView.addArrangedSubview(substrateBackgroundView)

        substrateBackgroundView.addSubview(substrateTextField)

        substrateTextField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8.0)
        }

        substrateBackgroundView.addSubview(substrateTitleLabel)
        substrateTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(8.0)
        }

        containerView.stackView.addArrangedSubview(ethereumCryptoTypeView)
        containerView.stackView.addArrangedSubview(ethereumBackgroundView)
        ethereumBackgroundView.addSubview(ethereumTextField)

        ethereumTextField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8.0)
        }

        ethereumBackgroundView.addSubview(ethereumTitleLabel)
        ethereumTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(8.0)
        }

        containerView.stackView.arrangedSubviews.forEach { view in
            view.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.triangularedViewHeight)
            }
        }
    }
}
