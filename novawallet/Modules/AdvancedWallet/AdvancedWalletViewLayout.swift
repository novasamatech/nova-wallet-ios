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

    let substrateCryptoTypeView: BorderedSubtitleActionView = {
        let view = UIFactory.default.createBorderSubtitleActionView()
        view.actionControl.imageIndicator.image = R.image.iconDropDown()
        return view
    }()

    let substrateBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()
    let substrateTextField: AnimatedTextField = UIFactory.default.createAnimatedTextField()

    let ethereumCryptoTypeView: BorderedSubtitleActionView = {
        let view = UIFactory.default.createBorderSubtitleActionView()
        view.fillColor = R.color.colorDisabledBackground()!
        view.highlightedFillColor = R.color.colorDisabledBackground()!
        return view
    }()

    let ethereumBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()
    let ethereumTextField: AnimatedTextField = UIFactory.default.createAnimatedTextField()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

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

        containerView.stackView.addArrangedSubview(substrateCryptoTypeView)
        containerView.stackView.addArrangedSubview(substrateBackgroundView)
        substrateBackgroundView.addSubview(substrateTextField)
        substrateTextField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(ethereumCryptoTypeView)
        containerView.stackView.addArrangedSubview(ethereumBackgroundView)
        ethereumBackgroundView.addSubview(ethereumTextField)
        ethereumTextField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.stackView.arrangedSubviews.forEach { view in
            view.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.triangularedViewHeight)
            }
        }
    }
}
