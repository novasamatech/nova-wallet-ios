import UIKit
import Foundation_iOS

/// Sort sheet for the subnet picker. Same shell as the validator filter
/// modal but the subnet picker has nothing meaningful to toggle on/off
/// (every subnet in the list is selectable), so the screen is sort-only
/// for v1. A "Hide empty subnets" toggle could slot in next to "Show:"
/// later if the design asks for it.
final class SubtensorSubnetFilterViewController: UIViewController {
    enum Sort: Int, CaseIterable {
        case totalStakeDesc
        case netuidAsc

        var title: String {
            switch self {
            case .totalStakeDesc: return "Total TAO staked"
            case .netuidAsc: return "Subnet number"
            }
        }
    }

    struct State: Equatable {
        var sort: Sort

        static let `default` = State(sort: .totalStakeDesc)
    }

    private var state: State
    private let initialState: State
    private let onApply: (State) -> Void

    private let sortButtons: [UIButton] = Sort.allCases.map { _ in UIButton(type: .custom) }

    private lazy var resetButton: UIBarButtonItem = {
        UIBarButtonItem(title: "Reset", style: .plain, target: self, action: #selector(tapReset))
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
        title = "Sort"
        navigationItem.rightBarButtonItem = resetButton

        setupLayout()
        bindState()
    }

    @objc func dismissAnimated() { dismiss(animated: true) }

    private func setupLayout() {
        view.addSubview(applyButton)
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 52)
        ])
        applyButton.addTarget(self, action: #selector(tapApply), for: .touchUpInside)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: applyButton.topAnchor, constant: -8)
        ])

        let header = UILabel()
        header.text = "Sort by:"
        header.font = .boldTitle3
        header.textColor = R.color.colorTextPrimary()
        stack.addArrangedSubview(header)

        for (index, option) in Sort.allCases.enumerated() {
            let button = sortButtons[index]
            button.contentHorizontalAlignment = .leading
            button.setImage(R.image.iconRadioButtonUnselected(), for: .normal)
            button.setImage(R.image.iconRadioButtonSelected(), for: .selected)
            button.setTitle("  \(option.title)", for: .normal)
            button.setTitleColor(R.color.colorTextPrimary(), for: .normal)
            button.titleLabel?.font = .regularSubheadline
            button.tag = option.rawValue
            button.addTarget(self, action: #selector(selectSort(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }

    private func bindState() {
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

    @objc private func selectSort(_ sender: UIButton) {
        guard let sort = Sort(rawValue: sender.tag) else { return }
        state.sort = sort
        bindState()
    }

    @objc private func tapReset() {
        state = .default
        bindState()
    }

    @objc private func tapApply() {
        onApply(state)
        dismiss(animated: true)
    }
}
