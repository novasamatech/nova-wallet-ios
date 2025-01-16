import UIKit
import UIKit_iOS

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

    var unitWidth: CGFloat {
        (UIScreen.main.bounds.width
            - UIConstants.horizontalInset * 2
            - contentInset.left
            - contentInset.right
            - spacing * 2) / 3
    }

    var spacing: CGFloat = Constants.itemsSpacing {
        didSet {
            rows.values.forEach { $0.spacing = spacing }
            stackView.spacing = spacing
        }
    }

    var contentInset: UIEdgeInsets = Constants.contentInset {
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

    func setupLayout() {
        addSubview(stackView)
        stackView.spacing = spacing
        stackView.layoutMargins = contentInset

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview().priority(.high)
        }
    }

    func setupStyle() {
        backgroundColor = .clear
        stackView.backgroundColor = .clear
    }

    func createWordButton(
        with text: String,
        for index: Int
    ) -> WordButton {
        let button = WordButton(preferredHeight: Constants.buttonHeight)
        button.contentInsets = Constants.itemContentInsets
        button.translatesAutoresizingMaskIntoConstraints = false
        button.controlBackgroundView?.shadowOpacity = 0.0
        button.controlBackgroundView?.fillColor = R.color.colorChipsBackground()!
        button.controlBackgroundView?.highlightedFillColor = .clear
        button.controlBackgroundView?.cornerRadius = Constants.itemCornerRadius
        button.changesContentOpacityWhenHighlighted = true
        button.controlContentView.textAlignment = .center
        button.controlContentView.text = text
        button.controlContentView.adjustsFontSizeToFitWidth = true
        button.tag = index

        addAction(for: button)

        button.snp.makeConstraints { make in
            make.width.equalTo(unitWidth)
            make.height.equalTo(Constants.buttonHeight)
        }

        return button
    }

    func bind(with units: [UnitType]) {
        self.units = units

        rows.values.forEach { $0.removeFromSuperview() }
        rows = [:]

        (0 ..< (units.count / 3)).forEach { index in
            let row = createRowView()
            rows[index] = row

            stackView.addArrangedSubview(row)
        }

        units
            .enumerated()
            .forEach { indexedUnit in
                let rowIndex = indexedUnit.offset / 3

                guard let row = rows[rowIndex] else {
                    return
                }

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
            self?.processInsertionCompletion(
                insertedButton: insertedButton,
                viewHolder: availableViewHolder,
                wordUnit: wordUnit
            )
        }

        transitionCoordinators[availableViewHolderIndex] = coordinator

        insertionClosure(coordinator)
    }

    func processInsertedButton(
        _ wordButton: WordButton,
        wordText: String
    ) {
        UIView.animate(withDuration: 0.2) {
            wordButton.controlContentView.alpha = 0
        } completion: { _ in
            wordButton.controlContentView.textAlignment = .center
            wordButton.controlContentView.text = wordText

            UIView.animate(withDuration: 0.2) {
                wordButton.controlContentView.alpha = 1
            }
        }
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
    func addAction(for button: UIControl) {
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

    func createViewHolder(for index: Int) -> UIView {
        let view = UIView()
        view.tag = index

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
        let viewHolder = createViewHolder(for: index)

        if case let .wordView(text) = unit {
            let wordButton = createWordButton(
                with: text,
                for: index
            )

            viewHolder.addSubview(wordButton)
        }

        row.addArrangedSubview(viewHolder)
    }

    func processInsertionCompletion(
        insertedButton: UIControl,
        viewHolder: UIView,
        wordUnit: UnitType
    ) {
        let index = viewHolder.tag
        insertedButton.tag = index

        units[index] = wordUnit
        addAction(for: insertedButton)
        transitionCoordinators[index] = nil

        guard
            let wordButton = insertedButton as? WordButton,
            case let .wordView(text) = wordUnit
        else {
            return
        }

        processInsertedButton(
            wordButton,
            wordText: text
        )
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
