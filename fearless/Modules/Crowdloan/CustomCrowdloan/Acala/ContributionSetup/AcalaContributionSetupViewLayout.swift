import UIKit

final class AcalaContributionSetupViewLayout: CrowdloanContributionSetupViewLayout {
    typealias Button = RadioButton<AcalaContributionMethod>
    let buttons: [Button] = {
        AcalaContributionMethod.allCases.map { Button(model: $0) }
    }()

    let infoLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorBlue()
        label.font = .p2Paragraph
        return label
    }()

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
        contentView.stackView.setCustomSpacing(16, after: buttonsStack)
        buttonsStack.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(44)
        }

        let infoIcon = UIImageView(image: R.image.iconInfoFilled()!.withRenderingMode(.alwaysTemplate))
        infoIcon.tintColor = R.color.colorBlue()

        let arrowIcon = UIImageView(image: R.image.iconSmallArrow()!.withRenderingMode(.alwaysTemplate))
        arrowIcon.tintColor = R.color.colorBlue()
        arrowIcon.contentMode = .center

        let infoStack = UIView.hStack(
            alignment: .center,
            spacing: 8,
            [infoIcon, infoLabel, arrowIcon, UIView()]
        )

        contentView.stackView.insertArrangedSubview(infoStack, at: titleLabelIndex + 2)
        contentView.stackView.setCustomSpacing(24, after: infoStack)
        infoStack.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }
        arrowIcon.snp.makeConstraints { $0.size.equalTo(12) }
    }

    override func applyLocalization() {
        super.applyLocalization()

        buttons.forEach { button in
            let title = button.model.title(for: locale)
            button.imageWithTitleView?.title = title
        }
        infoLabel.text = "Learn more about different contributions to Acala"
    }

    func bind(selectedMethod: AcalaContributionMethod) {
        buttons.forEach { $0.isSelected = $0.model == selectedMethod }
    }
}
