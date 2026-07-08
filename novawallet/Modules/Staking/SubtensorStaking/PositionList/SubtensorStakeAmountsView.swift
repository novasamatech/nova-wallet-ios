import UIKit
import UIKit_iOS
import SnapKit

/// "Your stake" card on the TAO staking dashboard. Shows aggregated root TAO
/// and per-subnet alpha balances as distinct rows (vs. a single aggregated
/// number). Mirrors the Avail/AZERO main staking layout but without
/// alpha→TAO conversion, so each token amount is shown in its native unit.
final class SubtensorStakeAmountsView: UIView {
    struct Row {
        /// Pre-formatted amount with unit, e.g. "10.0000 TAO" or "0.3031 α".
        let amountText: String
        /// Subnet badge, e.g. "SN8". `nil` for the root (TAO) row.
        let netuidBadge: String?
    }

    let backgroundView: BlockBackgroundView = {
        let view = BlockBackgroundView()
        view.sideLength = 12.0
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        return label
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8.0
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0.0
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func bind(title: String, rows: [Row]) {
        titleLabel.text = title

        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows.forEach { row in
            let view = SubtensorStakeRowView()
            view.bind(row: row)
            rowsStack.addArrangedSubview(view)
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(12.0, after: titleLabel)
        contentStack.addArrangedSubview(rowsStack)

        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(20.0)
            make.bottom.equalToSuperview().inset(24.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }
    }
}

private final class SubtensorStakeRowView: UIView {
    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .boldTitle1
        label.textColor = R.color.colorTextPrimary()
        return label
    }()

    let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.layer.borderWidth = 0.5
        label.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        return label
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8.0
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        stack.addArrangedSubview(amountLabel)
        stack.addArrangedSubview(badgeLabel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func bind(row: SubtensorStakeAmountsView.Row) {
        amountLabel.text = row.amountText
        if let badge = row.netuidBadge {
            badgeLabel.text = "  \(badge)  "
            badgeLabel.isHidden = false
        } else {
            badgeLabel.text = nil
            badgeLabel.isHidden = true
        }
    }
}
