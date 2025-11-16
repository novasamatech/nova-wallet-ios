import UIKit
import UIKit_iOS

final class GiftsOnboardingView: SCSingleActionLayoutView {
    let headerView = GiftsOnboardingHeaderView()

    let imageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.imageSiriGift()
    }

    let stepsStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = Constants.stepsSpacing
        view.alignment = .fill
        view.distribution = .fill
    }

    var actionButton: TriangularedButton {
        genericActionView
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins.top = Constants.topMargin

        addArrangedSubview(headerView, spacingAfter: Constants.headerToStepsSpacing)
        addArrangedSubview(stepsStackView, spacingAfter: Constants.stepsToImageSpacing)
        addArrangedSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.height.equalTo(Constants.imageHeight)
        }
    }

    override func setupStyle() {
        super.setupStyle()

        actionButton.applyDefaultStyle()
    }

    func bind(viewModel: GiftsOnboardingViewModel) {
        stepsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        headerView.locale = viewModel.locale

        viewModel.steps.forEach { step in
            let stepView = ProcessStepView()
            stepView.stepNumberView.titleLabel.text = step.number
            stepView.descriptionLabel.attributedText = step.attributedDescription

            stepsStackView.addArrangedSubview(stepView)
        }

        actionButton.imageWithTitleView?.title = viewModel.actionTitle
    }
}

// MARK: - Constants

private extension GiftsOnboardingViewLayout {
    enum Constants {
        static let headerToStepsSpacing: CGFloat = 16
        static let stepsToImageSpacing: CGFloat = 35.5
        static let imageHeight: CGFloat = 221
        static let stepsSpacing: CGFloat = 24
        static let topMargin: CGFloat = 16
    }
}
