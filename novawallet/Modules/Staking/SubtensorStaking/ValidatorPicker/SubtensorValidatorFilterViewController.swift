import UIKit
import Foundation_iOS

/// Filter + sort sheet for the Subtensor validator picker. Mirrors the
/// Polkadot Filters screen visually — "Show" section with toggles, "Sort by:"
/// section with radios, Apply button at the bottom — but only carries the
/// options that make sense for Bittensor v1:
///
///   - Show: Having onchain identity, Hide 100% commission
///   - Sort by: APR (high to low, default), Total stake (desc)
///
/// Polkadot's "Not slashed" / "Not oversubscribed" / "Limit per identity"
/// don't apply (no slashing model on Bittensor, no max-nominators concept,
/// single-select picker). APR sort surfaces the per-validator APR returned
/// by TaoStats; validators without APR data sink to the bottom.
final class SubtensorValidatorFilterViewController: UIViewController {
    enum Sort: Int, CaseIterable {
        case totalStakeDesc
        case aprDesc

        var title: String {
            switch self {
            case .totalStakeDesc: return "Total stake (TAO)"
            case .aprDesc: return "APR (high to low)"
            }
        }
    }

    struct State: Equatable {
        var requireIdentity: Bool
        var hideMaxCommission: Bool
        var sort: Sort

        static let `default` = State(
            requireIdentity: false,
            hideMaxCommission: false,
            sort: .aprDesc
        )
    }

    private var state: State
    private let initialState: State
    private let onApply: (State) -> Void

    private let identityToggle = UISwitch()
    private let hideMaxCommissionToggle = UISwitch()
    private let sortButtons: [UIButton] = Sort.allCases.map { _ in UIButton(type: .custom) }

    private lazy var resetButton: UIBarButtonItem = {
        UIBarButtonItem(
            title: "Reset",
            style: .plain,
            target: self,
            action: #selector(tapReset)
        )
    }()

    private lazy var applyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.imageWithTitleView?.title = "Apply"
        return button
    }()

    init(state: State, onApply: @escaping (State) -> Void) {
        self.state = state
        initialState = state
        self.onApply = onApply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        title = "Filters"
        navigationItem.rightBarButtonItem = resetButton

        setupLayout()
        bindState()
    }

    private func setupLayout() {
        let scroll = UIScrollView()
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(applyButton)
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 52)
        ])
        applyButton.addTarget(self, action: #selector(tapApply), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: applyButton.topAnchor, constant: -8)
        ])

        let content = UIStackView()
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 24
        content.isLayoutMarginsRelativeArrangement = true
        content.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        scroll.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        // Show section
        content.addArrangedSubview(makeSectionLabel(text: "Show"))

        let identityRow = makeToggleRow(
            title: "Having onchain identity",
            subtitle: "Hide validators without on-chain identity",
            toggle: identityToggle
        )
        content.addArrangedSubview(identityRow)

        let hideMaxRow = makeToggleRow(
            title: "Hide 100% commission",
            subtitle: "Some delegates take all rewards",
            toggle: hideMaxCommissionToggle
        )
        content.addArrangedSubview(hideMaxRow)

        identityToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        hideMaxCommissionToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        // Sort section
        content.addArrangedSubview(makeSectionLabel(text: "Sort by:"))

        for (index, option) in Sort.allCases.enumerated() {
            let button = sortButtons[index]
            button.contentHorizontalAlignment = .leading
            let row = makeRadioRow(title: option.title, button: button)
            button.tag = option.rawValue
            button.addTarget(self, action: #selector(selectSort(_:)), for: .touchUpInside)
            content.addArrangedSubview(row)
        }
    }

    private func makeSectionLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldTitle3
        label.textColor = R.color.colorTextPrimary()
        return label
    }

    private func makeToggleRow(title: String, subtitle: String?, toggle: UISwitch) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .regularSubheadline
        titleLabel.textColor = R.color.colorTextPrimary()
        titleLabel.numberOfLines = 0

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)

        if let subtitle = subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = .caption1
            subtitleLabel.textColor = R.color.colorTextSecondary()
            subtitleLabel.numberOfLines = 0
            textStack.addArrangedSubview(subtitleLabel)
        }

        let row = UIStackView(arrangedSubviews: [textStack, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 16
        return row
    }

    private func makeRadioRow(title: String, button: UIButton) -> UIView {
        button.setImage(R.image.iconRadioButtonUnselected(), for: .normal)
        button.setImage(R.image.iconRadioButtonSelected(), for: .selected)
        button.setTitle("  \(title)", for: .normal)
        button.setTitleColor(R.color.colorTextPrimary(), for: .normal)
        button.titleLabel?.font = .regularSubheadline
        return button
    }

    private func bindState() {
        identityToggle.isOn = state.requireIdentity
        hideMaxCommissionToggle.isOn = state.hideMaxCommission
        for (index, option) in Sort.allCases.enumerated() {
            sortButtons[index].isSelected = (state.sort == option)
        }
        resetButton.isEnabled = state != .default
        updateApplyEnabledState()
    }

    private func updateApplyEnabledState() {
        let changed = state != initialState
        if changed {
            applyButton.applyEnabledStyle()
            applyButton.isUserInteractionEnabled = true
        } else {
            applyButton.applyDisabledStyle()
            applyButton.isUserInteractionEnabled = false
        }
    }

    @objc private func toggleChanged() {
        state.requireIdentity = identityToggle.isOn
        state.hideMaxCommission = hideMaxCommissionToggle.isOn
        resetButton.isEnabled = state != .default
        updateApplyEnabledState()
    }

    @objc private func selectSort(_ sender: UIButton) {
        guard let sort = Sort(rawValue: sender.tag) else { return }
        state.sort = sort
        for (index, option) in Sort.allCases.enumerated() {
            sortButtons[index].isSelected = (sort == option)
        }
        resetButton.isEnabled = state != .default
        updateApplyEnabledState()
    }

    @objc private func tapReset() {
        state = .default
        bindState()
    }

    @objc private func tapApply() {
        onApply(state)
        dismiss(animated: true)
    }

    @objc func dismissAnimated() {
        dismiss(animated: true)
    }
}
