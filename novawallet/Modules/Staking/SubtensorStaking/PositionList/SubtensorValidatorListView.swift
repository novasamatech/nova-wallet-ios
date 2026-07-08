import UIKit
import UIKit_iOS
import SubstrateSdk
import SnapKit

/// Inline "Your validator" card on the TAO Staking dashboard. Shows the
/// validator name + hotkey + amount staked for every validator the user
/// holds a position with on the entry netuid.
///
/// This lifts the per-validator detail that used to live behind the
/// "Your positions" drill-in directly onto the dashboard, mirroring how
/// AZERO surfaces the user's pool.
final class SubtensorValidatorListView: UIView {
    let backgroundView: BlockBackgroundView = {
        let view = BlockBackgroundView()
        view.sideLength = 12.0
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func bind(title: String, rows: [SubtensorPositionViewModel]) {
        titleLabel.text = title

        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows.enumerated().forEach { index, row in
            let view = SubtensorValidatorRowView()
            view.bind(viewModel: row, showSeparator: index < rows.count - 1)
            rowsStack.addArrangedSubview(view)
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(4.0, after: titleLabel)
        contentStack.addArrangedSubview(rowsStack)

        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14.0)
            make.bottom.equalToSuperview().inset(8.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }
    }
}

private final class SubtensorValidatorRowView: UIView {
    private let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = .clear
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldSubheadline
        label.textColor = R.color.colorTextPrimary()
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let hotkeyLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldSubheadline
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .right
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private let separator: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorDivider()
        return view
    }()

    private let leftStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func bind(viewModel: SubtensorPositionViewModel, showSeparator: Bool) {
        if let icon = viewModel.identicon {
            iconView.bind(icon: icon)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }

        nameLabel.text = viewModel.nameText
        if viewModel.nameIsAddress {
            nameLabel.font = .systemFont(ofSize: 13, weight: .regular).monospaced()
            hotkeyLabel.isHidden = true
        } else {
            nameLabel.font = .semiBoldSubheadline
            hotkeyLabel.text = viewModel.shortHotkey
            hotkeyLabel.isHidden = viewModel.shortHotkey == nil
        }

        amountLabel.text = viewModel.amountText
        separator.isHidden = !showSeparator
    }

    private func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }

        addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        leftStack.addArrangedSubview(nameLabel)
        leftStack.addArrangedSubview(hotkeyLabel)

        addSubview(leftStack)
        leftStack.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(amountLabel.snp.leading).offset(-12)
            make.top.greaterThanOrEqualToSuperview().offset(8)
            make.bottom.lessThanOrEqualToSuperview().offset(-8)
        }

        addSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }

        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(56)
        }
    }
}

private extension UIFont {
    func monospaced() -> UIFont {
        let descriptor = fontDescriptor.withDesign(.monospaced) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
