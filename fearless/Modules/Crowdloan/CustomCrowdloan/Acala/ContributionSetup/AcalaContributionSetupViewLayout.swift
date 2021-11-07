import UIKit
import SoraUI

final class AcalaContributionSetupViewLayout: CrowdloanContributionSetupViewLayout {
    typealias Button = RadioButton<AcalaContributionMethod>
    let buttons: [Button] = {
        AcalaContributionMethod.allCases.map { Button(model: $0) }
    }()

    let acalaLearnMoreView: BackgroundedContentControl = AcalaLearnMoreView()

    override func setupLayout() {
        super.setupLayout()

        guard
            let titleLabelIndex = contentView.stackView.arrangedSubviews.firstIndex(of: contributionTitleLabel) else {
            return
        }

        let buttonsStack = UIView.hStack(
            distribution: .fillEqually,
            spacing: 16,
            buttons
        )

        contentView.stackView.insertArrangedSubview(buttonsStack, at: titleLabelIndex + 1)
        buttonsStack.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(44)
        }

        contentView.stackView.insertArrangedSubview(acalaLearnMoreView, at: titleLabelIndex + 2)
        acalaLearnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }
    }

    override func applyLocalization() {
        super.applyLocalization()

        buttons.forEach { button in
            let title = button.model.title(for: locale)
            button.imageWithTitleView?.title = title
        }
        if let acalaLearnMoreView = acalaLearnMoreView as? AcalaLearnMoreView {
            acalaLearnMoreView.titleLabel.text = R.string.localizable
                .crowdloanAcalaLearnMore(preferredLanguages: locale.rLanguages)
        }
    }

    func bind(selectedMethod: AcalaContributionMethod) {
        buttons.forEach { $0.isSelected = $0.model == selectedMethod }
    }
}

private final class AcalaLearnMoreView: BackgroundedContentControl {
    let iconView: UIImageView = {
        let view = UIImageView()
        let image = R.image.iconInfoFilled()!.withRenderingMode(.alwaysTemplate)
        view.image = image
        view.tintColor = R.color.colorNovaBlue()!
        view.contentMode = .scaleAspectFit
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorNovaBlue()
        return label
    }()

    let arrowIconView: UIView = {
        let imageView = UIImageView()
        let image = R.image.iconSmallArrow()!.withRenderingMode(.alwaysTemplate)
        imageView.image = image
        imageView.tintColor = R.color.colorNovaBlue()!
        // imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let shapeView = ShapeView()
        shapeView.isUserInteractionEnabled = false
        shapeView.fillColor = .clear
        shapeView.highlightedFillColor = R.color.colorHighlightedAccent()!
        backgroundView = shapeView

        contentInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.top,
            width: max(bounds.width - contentInsets.left - contentInsets.right, 0),
            height: max(bounds.height - contentInsets.top - contentInsets.bottom, 0)
        )
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 56
        )
    }

    private func setupLayout() {
        let baseView = UIView()
        baseView.isUserInteractionEnabled = false

        baseView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(16)
        }

        baseView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }

        baseView.addSubview(arrowIconView)
        arrowIconView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(4)
            make.size.equalTo(24)
        }

        contentView = baseView

        baseView.autoresizingMask = [.flexibleWidth]
    }
}
