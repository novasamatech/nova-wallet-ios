import UIKit
import SoraUI

final class AcalaContributionSetupViewLayout: CrowdloanContributionSetupViewLayout {
    typealias Button = RadioButton<AcalaContributionMethod>
    let buttons: [Button] = {
        AcalaContributionMethod.allCases.map { Button(model: $0) }
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorNovaBlue()
        label.numberOfLines = 0
        return label
    }()

    private(set) var acalaLearnMoreView: RowView<UIView>!

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

        let iconView = UIImageView()
        let iconimage = R.image.iconInfoFilled()!.withRenderingMode(.alwaysTemplate)
        iconView.image = iconimage
        iconView.tintColor = R.color.colorNovaBlue()!
        iconView.contentMode = .scaleAspectFit

        let arrowIconView = UIImageView()
        let arrowImage = R.image.iconSmallArrow()!.withRenderingMode(.alwaysTemplate)
        arrowIconView.image = arrowImage
        arrowIconView.tintColor = R.color.colorNovaBlue()!

        let content = UIView.hStack(alignment: .center, spacing: 4, [iconView, titleLabel, arrowIconView])
        content.setCustomSpacing(8, after: iconView)
        iconView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }
        arrowIconView.snp.makeConstraints { make in
            make.size.equalTo(24)
        }

        acalaLearnMoreView = RowView(contentView: content)
        acalaLearnMoreView.contentInsets = .init(top: 16, left: 20, bottom: 24, right: 29)
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
        titleLabel.text = R.string.localizable.crowdloanAcalaLearnMore(preferredLanguages: locale.rLanguages)
    }

    func bind(selectedMethod: AcalaContributionMethod) {
        buttons.forEach { $0.isSelected = $0.model == selectedMethod }
    }
}
