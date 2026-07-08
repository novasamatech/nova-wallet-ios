import UIKit
import UIKit_iOS
import SnapKit

/// Expandable "Staking info" footer card for the TAO dashboard. Mirrors
/// Avail/AZERO's `NetworkInfoView` but trimmed to the two facts we can
/// confidently surface today: minimum stake and unstaking period.
final class SubtensorStakingInfoView: UIView {
    struct Model {
        let minStake: String
        let unstakingPeriod: String
    }

    private enum Constants {
        static let headerHeight: CGFloat = 48.0
        static let rowHeight: CGFloat = 44.0
        static let bottomInset: CGFloat = 8.0
        static let visibleRowCount: CGFloat = 2
    }

    let backgroundView = BlockBackgroundView()

    /// Header strip — tapping anywhere on it toggles expansion. The chevron
    /// rotates to telegraph the state change.
    private let headerButton = UIControl()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Staking info"
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularSubheadline
        return label
    }()

    private let chevronView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconArrowUp()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .center
        view.transform = CGAffineTransform(rotationAngle: .pi) // start pointing down (collapsed)
        return view
    }()

    private let rowsContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0.0
        return stack
    }()

    private let minStakeRow = SubtensorStakingInfoView.makeRow(separator: true)
    private let unstakingRow = SubtensorStakingInfoView.makeRow(separator: false)

    private var rowsHeightConstraint: Constraint?
    private var isExpanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        headerButton.addTarget(self, action: #selector(didTapHeader), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    func bind(model: Model) {
        minStakeRow.titleLabel.text = "Minimum stake"
        minStakeRow.valueTop.text = model.minStake

        unstakingRow.titleLabel.text = "Unstaking period"
        unstakingRow.valueTop.text = model.unstakingPeriod
    }

    @objc private func didTapHeader() {
        isExpanded.toggle()
        let targetHeight: CGFloat = isExpanded
            ? Constants.rowHeight * Constants.visibleRowCount + Constants.bottomInset
            : 0
        let chevronAngle: CGFloat = isExpanded ? 0 : .pi

        rowsHeightConstraint?.update(offset: targetHeight)

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            self.chevronView.transform = CGAffineTransform(rotationAngle: chevronAngle)
            self.layoutIfNeeded()
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(headerButton)
        headerButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(Constants.headerHeight)
        }

        headerButton.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.centerY.equalToSuperview()
        }

        headerButton.addSubview(chevronView)
        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16.0)
            make.centerY.equalToSuperview()
        }

        addSubview(rowsContainer)
        rowsContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(headerButton.snp.bottom)
            make.bottom.equalToSuperview()
            rowsHeightConstraint = make.height.equalTo(0).constraint
        }

        rowsContainer.addSubview(rowsStack)
        rowsStack.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16.0)
        }

        [minStakeRow, unstakingRow].forEach { row in
            rowsStack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.height.equalTo(Constants.rowHeight)
            }
        }
    }

    private static func makeRow(separator: Bool) -> TitleMultiValueView {
        let row = TitleMultiValueView()
        row.applySingleValueBlurStyle()
        if !separator {
            row.borderView.borderType = .none
        }
        return row
    }
}
