import UIKit
import UIKit_iOS

enum PVWelcomeMode: Int, CaseIterable {
    case pairPublicKey = 0
    case importPrivateKey = 1
}

final class PVWelcomeViewLayout: UIView, AdaptiveDesignable {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 8.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let actionButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle3
        view.numberOfLines = 0
    }

    var modeSegmentedControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackgroundOnBlack()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularSubheadline
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
        view.backgroundView.cornerRadius = 12
    }

    let integrationImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let step1: ProcessStepView = .create { view in
        view.stepNumberView.titleLabel.text = "1"
    }

    let step2: ProcessStepView = .create { view in
        view.stepNumberView.titleLabel.text = "2"
    }

    let step2DetailsHintView: IconDetailsView = .create { view in
        view.spacing = 6
        view.iconWidth = 18
        view.imageView.image = R.image.iconCheckmarkFilled()?.tinted(with: R.color.colorIconPositive()!)
        view.detailsLabel.apply(style: .footnotePositive)
    }

    let step2DetailsImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let step3: ProcessStepView = .create { view in
        view.stepNumberView.titleLabel.text = "3"
    }

    let step4: ProcessStepView = .create { view in
        view.stepNumberView.titleLabel.text = "4"
        view.isHidden = true
    }

    private var step2DetailsContainerView: UIView!
    private var step2DetailsStackView: UIStackView!

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setMode(_ mode: PVWelcomeMode) {
        switch mode {
        case .pairPublicKey:
            step4.isHidden = true
        case .importPrivateKey:
            step4.isHidden = false
        }
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

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(16.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(modeSegmentedControl)
        modeSegmentedControl.snp.makeConstraints { make in
            make.height.equalTo(40.0)
        }
        containerView.stackView.setCustomSpacing(24.0, after: modeSegmentedControl)

        let imageScaleRatio: CGFloat = isAdaptiveWidthDecreased ? designScaleRatio.width : 1.0
        let integrationImageHeight = 88.0 * imageScaleRatio

        containerView.stackView.addArrangedSubview(integrationImageView)
        integrationImageView.snp.makeConstraints { make in
            make.height.equalTo(integrationImageHeight)
        }

        containerView.stackView.setCustomSpacing(32.0, after: integrationImageView)

        containerView.stackView.addArrangedSubview(step1)

        containerView.stackView.setCustomSpacing(24.0, after: step1)

        containerView.stackView.addArrangedSubview(step2)
        containerView.stackView.setCustomSpacing(12.0, after: step2)

        step2DetailsContainerView = UIView()
        step2DetailsStackView = UIStackView()
        step2DetailsStackView.axis = .vertical
        step2DetailsStackView.spacing = 6.0
        step2DetailsStackView.alignment = .leading

        step2DetailsContainerView.addSubview(step2DetailsStackView)
        containerView.stackView.addArrangedSubview(step2DetailsContainerView)

        step2DetailsStackView.addArrangedSubview(step2DetailsImageView)

        let step2DetailsOffset = 2 * step2.stepNumberView.backgroundView.cornerRadius + step2.spacing
        step2DetailsStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(step2DetailsOffset)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
        }

        containerView.stackView.setCustomSpacing(24.0, after: step2DetailsContainerView)

        containerView.stackView.addArrangedSubview(step3)
        containerView.stackView.setCustomSpacing(24.0, after: step3)

        containerView.stackView.addArrangedSubview(step4)
    }

    func showStep2Hint(with text: String) {
        hideStep2Hint()
        step2DetailsHintView.detailsLabel.text = text
        step2DetailsStackView.insertArrangedSubview(step2DetailsHintView, at: 0)
    }

    func hideStep2Hint() {
        step2DetailsHintView.removeFromSuperview()
    }
}
