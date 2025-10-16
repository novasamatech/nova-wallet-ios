import UIKit
import UIKit_iOS

final class GiftsOnboardingViewLayout: SCSingleActionLayoutView {
    private enum Constants {
        static let titleTopSpacing: CGFloat = 12
        static let titleToSubtitleSpacing: CGFloat = 8
        static let subtitleToImageSpacing: CGFloat = 24
        static let imageHeight: CGFloat = 180
        static let imageToStepsSpacing: CGFloat = 24
        static let stepsSpacing: CGFloat = 16
        static let stepsToLearnMoreSpacing: CGFloat = 24
    }
    
    let titleLabel: UILabel = .create { label in
        label.apply(style: .boldTitle1Primary)
        label.numberOfLines = 0
        label.textAlignment = .left
    }
    
    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
        label.numberOfLines = 0
        label.textAlignment = .left
    }
    
    let imageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.imageCatsGift()
    }
    
    let stepsStackView: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = Constants.stepsSpacing
        view.alignment = .fill
        view.distribution = .fill
    }
    
    let learnMoreView: LinkView = .create { view in
        view.mode = .iconDetails
    }
    
    var actionButton: TriangularedButton {
        genericActionView
    }
    
    override func setupLayout() {
        super.setupLayout()
        
        stackView.layoutMargins.top = Constants.titleTopSpacing
        
        addArrangedSubview(titleLabel, spacingAfter: Constants.titleToSubtitleSpacing)
        addArrangedSubview(subtitleLabel, spacingAfter: Constants.subtitleToImageSpacing)
        addArrangedSubview(imageView, spacingAfter: Constants.imageToStepsSpacing)
        
        imageView.snp.makeConstraints { make in
            make.height.equalTo(Constants.imageHeight)
        }
        
        addArrangedSubview(stepsStackView, spacingAfter: Constants.stepsToLearnMoreSpacing)
        addArrangedSubview(learnMoreView)
    }
    
    override func setupStyle() {
        super.setupStyle()
        
        actionButton.applyDefaultStyle()
    }
    
    func bind(viewModel: GiftsOnboardingViewModel) {
        // Set title and subtitle
        titleLabel.text = viewModel.title
        
        if let subtitle = viewModel.subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
        
        // Clear existing steps
        stepsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add step views
        viewModel.steps.forEach { step in
            let stepView = ProcessStepView()
            stepView.stepNumberView.titleLabel.text = step.number
            stepView.descriptionLabel.attributedText = step.attributedDescription
            
            stepsStackView.addArrangedSubview(stepView)
        }
        
        // Configure learn more
        learnMoreView.actionButton.imageWithTitleView?.title = viewModel.learnMoreTitle
        
        // Configure action button
        actionButton.imageWithTitleView?.title = viewModel.actionTitle
    }
}
