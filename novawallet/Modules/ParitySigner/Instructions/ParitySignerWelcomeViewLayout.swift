import UIKit
import UIKit_iOS

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

    let step2DetailsView: IconDetailsView = {
        let view = IconDetailsView()
        view.imageView.image = R.image.iconAlgoItem()
        view.spacing = 6.0
        view.detailsLabel.textColor = R.color.colorTextPositive()
        view.detailsLabel.font = .regularFootnote
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

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(32.0, after: titleLabel)

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

        let step2DetailsContainerView = UIView()
        containerView.stackView.addArrangedSubview(step2DetailsContainerView)

        step2DetailsContainerView.addSubview(step2DetailsView)

        let step2DetailsOffset = 2 * step2.stepNumberView.backgroundView.cornerRadius + step2.spacing
        step2DetailsView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(step2DetailsOffset)
            make.trailing.equalToSuperview()
        }

        step2DetailsContainerView.addSubview(step2DetailsImageView)

        step2DetailsImageView.snp.makeConstraints { make in
            make.top.equalTo(step2DetailsView.snp.bottom).offset(6.0)
            make.leading.equalToSuperview().offset(step2DetailsOffset)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
        }

        containerView.stackView.setCustomSpacing(24.0, after: step2DetailsContainerView)

        containerView.stackView.addArrangedSubview(step3)
    }
}
