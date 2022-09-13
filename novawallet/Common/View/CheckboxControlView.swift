import UIKit

final class CheckboxControlView: ControlView<UIView, IconDetailsView> {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
        updateCheckboxState()

        addTarget(self, action: #selector(actionTap), for: .touchUpInside)
    }

    var isCheckboxed: Bool = false {
        didSet {
            updateCheckboxState()
        }
    }

    private func configureStyle() {
        controlContentView.iconWidth = 24.0
        controlContentView.spacing = 12.0

        controlContentView.detailsLabel.textColor = R.color.colorTransparentText()
        controlContentView.detailsLabel.font = .regularFootnote
    }

    private func updateCheckboxState() {
        if isCheckboxed {
            controlContentView.imageView.image = R.image.iconCheckbox()
        } else {
            controlContentView.imageView.image = R.image.iconCheckboxEmpty()
        }
    }

    @objc private func actionTap() {
        isCheckboxed = !isCheckboxed

        sendActions(for: .valueChanged)
    }
}
