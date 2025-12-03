import UIKit
import UIKit_iOS

enum ParitySignerWelcomeMode: Int, CaseIterable {
    case pairPublicKey = 0
    case importPrivateKey = 1
}

final class ParitySignerWelcomeViewLayout: UIView, AdaptiveDesignable {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 8.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldTitle3
        label.numberOfLines = 0
        return label
    }()

    let modeSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.insertSegment(withTitle: "", at: ParitySignerWelcomeMode.pairPublicKey.rawValue, animated: false)
        control.insertSegment(withTitle: "", at: ParitySignerWelcomeMode.importPrivateKey.rawValue, animated: false)
        control.selectedSegmentIndex = ParitySignerWelcomeMode.pairPublicKey.rawValue
        return control
    }()

    let integrationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let step1: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "1"
        return view
    }()

    let step2: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "2"
        return view
    }()

    let step2DetailsImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    let step3: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "3"
        return view
    }()

    let step4: ProcessStepView = {
        let view = ProcessStepView()
        view.stepNumberView.titleLabel.text = "4"
        view.isHidden = true
        return view
    }()

    private var step2DetailsContainerView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setMode(_ mode: ParitySignerWelcomeMode) {
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
            make.height.equalTo(36.0)
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
        containerView.stackView.addArrangedSubview(step2DetailsContainerView)

        step2DetailsContainerView.addSubview(step2DetailsImageView)

        let step2DetailsOffset = 2 * step2.stepNumberView.backgroundView.cornerRadius + step2.spacing
        step2DetailsImageView.snp.makeConstraints { make in
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
}
