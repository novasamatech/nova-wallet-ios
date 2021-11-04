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

        // TODO: Add custom  "Learn more about different contributions to Acala" backgroundControl
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
