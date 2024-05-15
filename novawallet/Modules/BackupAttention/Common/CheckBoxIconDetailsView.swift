import UIKit
import SoraFoundation
import SoraUI

final class CheckBoxIconDetailsView: RowView<GenericPairValueView<UIImageView, IconDetailsView>> {
    var attentionImageView: UIImageView {
        rowContentView.fView
    }

    var checkboxImageView: UIImageView {
        rowContentView.sView.imageView
    }

    var detailsLabel: UILabel {
        rowContentView.sView.detailsLabel
    }

    private var checked: Bool = false {
        didSet {
            updateCheckboxState()
        }
    }

    private var viewModel: Model?

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        updateCheckboxState()
    }

    func bind(viewModel: Model) {
        self.viewModel = viewModel
        attentionImageView.image = viewModel.image
        checked = viewModel.checked

        // TODO: Localize
        switch viewModel.text.value(for: Locale.current) {
        case let .attributed(text):
            detailsLabel.attributedText = text
        case let .raw(text):
            detailsLabel.text = text
        }

        setNeedsLayout()
    }

    @objc func actionTouchUpInside() {
        guard let viewModel else { return }

        viewModel.onCheck(viewModel.id)
    }
}

// MARK: Model

extension CheckBoxIconDetailsView {
    struct Model: Identifiable, Hashable {
        let id = UUID()

        let image: UIImage?
        let text: LocalizableResource<Text>
        let checked: Bool

        let onCheck: (UUID) -> Void

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Model, rhs: Model) -> Bool {
            lhs.id == rhs.id
        }
    }

    enum Text {
        case raw(String)
        case attributed(NSAttributedString)
    }
}

// MARK: Private

private extension CheckBoxIconDetailsView {
    func configure() {
        rowContentView.makeVertical()
        rowContentView.spacing = 12
        rowContentView.stackView.distribution = .fill

        attentionImageView.snp.makeConstraints { make in
            make.size.equalTo(26)
        }

        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        roundedBackgroundView.roundingCorners = .allCorners
        roundedBackgroundView.cornerRadius = 12.0

        attentionImageView.contentMode = .scaleAspectFit

        contentInsets.left = 12
        contentInsets.right = 12
        contentInsets.bottom = 12
        contentInsets.top = 16

        addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)

        setNeedsLayout()
    }

    func updateCheckboxState() {
        if checked {
            checkboxImageView.image = R.image.iconCheckbox()
        } else {
            checkboxImageView.image = R.image.iconCheckboxEmpty()
        }
    }
}
