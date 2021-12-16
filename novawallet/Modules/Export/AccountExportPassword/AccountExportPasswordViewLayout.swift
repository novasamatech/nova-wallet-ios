import UIKit
import SoraUI

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
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let setPasswordBackroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let setPasswordView: AnimatedTextField = {
        let view = UIFactory.default.createAnimatedTextField()

        return view
    }()

    let setPasswordEyeButton: RoundedButton = {
        let button = RoundedButton()
        button.roundedBackgroundView?.fillColor = .clear
        button.roundedBackgroundView?.highlightedFillColor = .clear
        button.roundedBackgroundView?.strokeColor = .clear
        button.roundedBackgroundView?.highlightedStrokeColor = .clear
        button.roundedBackgroundView?.shadowOpacity = 0.0
        button.imageWithTitleView?.iconImage = R.image.iconEye()
        return button
    }()

    let confirmPasswordBackroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let confirmPasswordView: AnimatedTextField = {
        let view = UIFactory.default.createAnimatedTextField()

        return view
    }()

    let confirmPasswordEyeButton: RoundedButton = {
        let button = RoundedButton()
        button.roundedBackgroundView?.fillColor = .clear
        button.roundedBackgroundView?.highlightedFillColor = .clear
        button.roundedBackgroundView?.strokeColor = .clear
        button.roundedBackgroundView?.highlightedStrokeColor = .clear
        button.roundedBackgroundView?.shadowOpacity = 0.0
        button.imageWithTitleView?.iconImage = R.image.iconEye()
        return button
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
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

        containerView.stackView.addArrangedSubview(setPasswordBackroundView)
        setPasswordBackroundView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        setPasswordBackroundView.addSubview(setPasswordEyeButton)
        setPasswordEyeButton.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.width.equalTo(UIConstants.triangularedViewHeight)
        }

        setPasswordBackroundView.addSubview(setPasswordView)
        setPasswordView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(setPasswordEyeButton.snp.leading)
        }

        containerView.stackView.setCustomSpacing(16.0, after: setPasswordBackroundView)

        containerView.stackView.addArrangedSubview(confirmPasswordBackroundView)
        confirmPasswordBackroundView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        confirmPasswordBackroundView.addSubview(confirmPasswordEyeButton)
        confirmPasswordEyeButton.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.width.equalTo(UIConstants.triangularedViewHeight)
        }

        confirmPasswordBackroundView.addSubview(confirmPasswordView)
        confirmPasswordView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(confirmPasswordEyeButton.snp.leading)
        }
    }
}
