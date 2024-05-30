import UIKit
import SoraUI

protocol MnemonicGridViewDelegate: AnyObject {
    func didTap(
        _ mnemonicView: MnemonicGridView,
        _ unit: MnemonicGridView.UnitType
    )
}

class MnemonicGridView: UIView {
    typealias WordButton = ControlView<RoundedView, UILabel>
    typealias Placeholder = UIView

    weak var delegate: MnemonicGridViewDelegate?

    var units: [UnitType] = []
    private var rows: [Int: UIStackView] = [:]
    private var transitionCoordinators: [Int: GridUnitTransitionCoordinatorSourceProtocol] = [:]

    private var currentProposedButton: WordButton?

    let stackView: UIStackView = .create { view in
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .fill
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isLayoutMarginsRelativeArrangement = true
    }

    open var unitWidth: CGFloat {
        (UIScreen.main.bounds.width
            - UIConstants.horizontalInset * 2
            - contentInset.left
            - contentInset.right
            - spacing * 2) / 3
    }

    open var spacing: CGFloat = Constants.itemsSpacing {
        didSet {
            rows.values.forEach { $0.spacing = spacing }
            stackView.spacing = spacing
        }
    }

    open var contentInset: UIEdgeInsets = Constants.contentInset {
        didSet {
            stackView.layoutMargins = contentInset
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func setupLayout() {
        addSubview(stackView)
        stackView.spacing = spacing
        stackView.layoutMargins = contentInset

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview().priority(.high)
        }
    }

    open func setupStyle() {
        backgroundColor = .clear
        stackView.backgroundColor = .clear
    }

    func bind(with units: [UnitType]) {
        self.units = units

        rows.values.forEach { $0.removeFromSuperview() }
        rows = [:]

        (0 ..< (units.count / 3)).forEach { [weak self] index in
            guard let self else { return }
            let row = createRowView()
            rows[index] = row

            stackView.addArrangedSubview(row)
        }

        units
            .enumerated()
            .forEach { [weak self] indexedUnit in
                let rowIndex = indexedUnit.offset / 3

                guard
                    let self,
                    let row = rows[rowIndex]
                else { return }

                addView(
                    for: indexedUnit.element,
                    with: indexedUnit.offset,
                    to: row
                )
            }
    }

    func requestWordInsert(
        wordUnit: UnitType,
        _ insertionClosure: (_ coordinator: GridUnitTransitionCoordinatorSourceProtocol?) -> Void
    ) {
        guard
            let availableViewHolderIndex = units.firstIndex(where: { $0 == .viewHolder }),
            let row = rows[availableViewHolderIndex / 3],
            let availableViewHolder = row
            .arrangedSubviews
            .first(where: { $0.tag == availableViewHolderIndex })
        else {
            insertionClosure(.none)

            return
        }

        let coordinator = GridUnitTransitionCoordinator()

        coordinator.setupInsertion(
            viewHolder: availableViewHolder,
            parentView: row
        ) { [weak self] insertedButton in
            insertedButton.tag = availableViewHolder.tag

            self?.units[availableViewHolderIndex] = wordUnit
            self?.addAction(for: insertedButton)
            self?.transitionCoordinators[availableViewHolderIndex] = nil
        }

        transitionCoordinators[availableViewHolderIndex] = coordinator

        insertionClosure(coordinator)
    }

    func setupProposition(for coordinator: GridUnitTransitionCoordinatorSourceProtocol) {
        guard let currentProposedButton else { return }

        coordinator.setupProposition(
            view: currentProposedButton,
            onFinish: { [weak self] in
                let index = currentProposedButton.tag
                self?.units[index] = .viewHolder
            }
        )
    }
}

// MARK: Private

private extension MnemonicGridView {
    func createWordButton(
        with text: String,
        number: Int
    ) -> WordButton {
        let button = WordButton(preferredHeight: Constants.buttonHeight)
        button.contentInsets = Constants.itemContentInsets
        button.translatesAutoresizingMaskIntoConstraints = false
        button.controlBackgroundView?.shadowOpacity = 0.0
        button.controlBackgroundView?.fillColor = R.color.colorChipsBackground()!
        button.controlBackgroundView?.highlightedFillColor = .clear
        button.controlBackgroundView?.cornerRadius = Constants.itemCornerRadius
        button.changesContentOpacityWhenHighlighted = true
        button.controlContentView.attributedText = NSAttributedString.coloredItems(
            ["\(number)"],
            formattingClosure: { String(format: "%@ \(text)", $0[0]) },
            color: R.color.colorTextSecondary()!
        )

        addAction(for: button)

        button.snp.makeConstraints { make in
            make.width.equalTo(unitWidth)
            make.height.equalTo(Constants.buttonHeight)
        }

        return button
    }

    open func addAction(for button: UIControl) {
        button.addTarget(
            self,
            action: #selector(wordButtonAction(sender:)),
            for: .touchUpInside
        )
    }

    @objc func wordButtonAction(sender: UIControl) {
        guard let button = sender as? WordButton else { return }

        let index = button.tag

        currentProposedButton = button
        delegate?.didTap(self, units[index])
    }

    func createViewHolder() -> UIView {
        let view = UIView()
        let width = unitWidth

        view.snp.makeConstraints { make in
            make.width.equalTo(unitWidth)
            make.height.equalTo(Constants.buttonHeight)
        }

        return view
    }

    func createRowView() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fill
        row.spacing = spacing

        return row
    }

    func addView(
        for unit: UnitType,
        with index: Int,
        to row: UIStackView
    ) {
        let viewHolder = createViewHolder()

        if case let .wordView(text) = unit {
            let wordButton = createWordButton(
                with: text,
                number: index + 1
            )

            wordButton.tag = index

            viewHolder.addSubview(wordButton)
        }

        viewHolder.tag = index

        row.addArrangedSubview(viewHolder)
    }
}

// MARK: Constants

private extension MnemonicGridView {
    enum Constants {
        static let itemsSpacing: CGFloat = 16
        static let itemCornerRadius: CGFloat = 8
        static let buttonHeight: CGFloat = 33.0
        static let contentInset: UIEdgeInsets = .init(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
        )
        static let itemContentInsets = UIEdgeInsets(
            top: 6.0,
            left: 11.0,
            bottom: 8.0,
            right: 11.0
        )
    }
}

extension MnemonicGridView {
    enum UnitType: Hashable, Equatable {
        case viewHolder
        case wordView(text: String)
    }
}
