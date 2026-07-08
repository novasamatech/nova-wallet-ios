import UIKit
import SubstrateSdk

/// Single-row validator cell modelled on Nova's `CustomValidatorCell` density:
///   [24pt identicon]  [name OR truncated hotkey]   [primary metric]
///                                                  [aux caption]
///
/// Subtensor v1 surfaces commission as the primary metric and total stake as
/// the aux caption. No selection checkbox (single-select; tap-to-pop) and no
/// info button (no validator-detail screen yet — to be added once one exists).
final class SubtensorValidatorTableViewCell: UITableViewCell {
    static let reuseId = "SubtensorValidatorTableViewCell"

    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = .clear
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextPrimary()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textAlignment = .right
        label.textColor = R.color.colorTextPositive()
        return label
    }()

    let detailsAuxLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textAlignment = .right
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    private let detailsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = 2
        stack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear
        selectionStyle = .default

        let bgView = UIView()
        bgView.backgroundColor = R.color.colorCellBackgroundPressed()
        selectedBackgroundView = bgView

        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        detailsStack.addArrangedSubview(detailsLabel)
        detailsStack.addArrangedSubview(detailsAuxLabel)
        contentView.addSubview(detailsStack)
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            detailsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            detailsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            detailsStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 8),
            detailsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])

        contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailsStack.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func bind(viewModel: SubtensorValidatorCellViewModel) {
        if let icon = viewModel.identicon {
            iconView.bind(icon: icon)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }

        if let name = viewModel.displayName, !name.isEmpty {
            titleLabel.text = name
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.font = .regularFootnote
        } else {
            titleLabel.text = viewModel.shortHotkey
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.font = .regularFootnote.monospaced()
        }

        detailsLabel.text = viewModel.aprText
        detailsAuxLabel.text = viewModel.commissionText
    }
}

private extension UIFont {
    func monospaced() -> UIFont {
        let descriptor = fontDescriptor.withDesign(.monospaced) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
