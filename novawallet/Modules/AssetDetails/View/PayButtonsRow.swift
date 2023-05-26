import UIKit

final class PayButtonsRow: RowView<UIStackView>, StackTableViewCellProtocol {
    init(frame: CGRect, views: [UIView]) {
        super.init(frame: frame)

        configureStyle()
        views.forEach(rowContentView.addArrangedSubview)
    }

    private func configureStyle() {
        preferredHeight = 80
        borderView.strokeColor = R.color.colorDivider()!
        isUserInteractionEnabled = true
        rowContentView.isUserInteractionEnabled = true
        rowContentView.distribution = .fillEqually
        rowContentView.axis = .horizontal
        backgroundColor = .clear

        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        roundedBackgroundView.cornerRadius = 12
        roundedBackgroundView.roundingCorners = .allCorners
    }
}
