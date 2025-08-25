import UIKit
import SnapKit
import UIKit_iOS

protocol PriceChartPeriodControlDelegate: AnyObject {
    func periodControl(
        _ control: PriceChartPeriodControl,
        didSelect period: PriceChartPeriodViewModel
    )
}

final class PriceChartPeriodControl: UIView {
    weak var delegate: PriceChartPeriodControlDelegate?
    let periods: [PriceChartPeriodViewModel]

    private let layoutAnimator: BlockViewAnimatorProtocol
    private let transformAnimator: BlockViewAnimatorProtocol

    private var buttons: [UIButton] = []
    private var selectedPeriod: PriceChartPeriodViewModel

    private lazy var stackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.spacing = Constants.stackSpacing
        view.distribution = .fillEqually
    }

    private lazy var selectionBackground: UIView = .create { view in
        view.backgroundColor = R.color.colorSegmentedTabActive()
        view.layer.cornerRadius = Constants.cornerRadius
    }

    init(viewModel: PriceChartPeriodControlViewModel) {
        periods = viewModel.periods
        selectedPeriod = viewModel.periods[viewModel.selectedPeriodIndex]

        layoutAnimator = BlockViewAnimator(
            duration: 0.3,
            options: [.curveEaseInOut]
        )
        transformAnimator = BlockViewAnimator(
            duration: 0.1,
            options: [.curveEaseOut]
        )

        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension PriceChartPeriodControl {
    // MARK: Setup

    func setup() {
        setupStyle()
        setupLayout()
    }

    func setupLayout() {
        addSubview(stackView)

        insertSubview(
            selectionBackground,
            belowSubview: stackView
        )

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.stackInsets)
        }

        setupPeriodButtons()
        updateSelectionBackground(animated: false)
    }

    func setupStyle() {
        backgroundColor = .clear
        layer.cornerRadius = 8.0
    }

    func setupPeriodButtons() {
        periods.forEach { period in
            let button = createPeriodButton(for: period)
            buttons.append(button)
            stackView.addArrangedSubview(button)

            button.snp.makeConstraints { make in
                make.size.equalTo(Constants.buttonSize)
            }
        }
    }

    func createPeriodButton(for period: PriceChartPeriodViewModel) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(period.text, for: .normal)
        button.titleLabel?.font = .regularFootnote

        button.addTarget(
            self,
            action: #selector(periodButtonTapped(_:)),
            for: .touchUpInside
        )

        updateButton(button, isSelected: period == selectedPeriod)

        return button
    }

    // MARK: - Updates

    func updateButton(
        _ button: UIButton,
        isSelected: Bool
    ) {
        let primaryColor = R.color.colorTextPrimary()!
        let secondaryColor = R.color.colorTextSecondary()!

        button.setTitleColor(
            isSelected ? primaryColor : secondaryColor,
            for: .normal
        )
    }

    func updateSelectionBackground(animated: Bool) {
        guard
            let index = periods.firstIndex(of: selectedPeriod),
            index < buttons.count,
            let selectedButton = buttons[safe: index]
        else { return }

        let constraintsUpdateClosure: () -> Void = { [weak self] in
            self?.selectionBackground.snp.remakeConstraints { make in
                make.center.equalTo(selectedButton)
                make.size.equalTo(Constants.selectedBackgroundSize)
            }
        }

        if animated {
            transformAnimator.animate { [weak self] in
                self?.selectionBackground.transform = CGAffineTransform(
                    scaleX: Constants.animationScale,
                    y: Constants.animationScale
                )
            } completionBlock: { [weak self] _ in
                constraintsUpdateClosure()

                self?.layoutAnimator.animate {
                    self?.layoutIfNeeded()
                } completionBlock: { _ in
                    self?.transformAnimator.animate(
                        block: {
                            self?.selectionBackground.transform = .identity
                        },
                        completionBlock: nil
                    )
                }
            }
        } else {
            constraintsUpdateClosure()
            layoutIfNeeded()
        }
    }

    // MARK: - Actions

    @objc func periodButtonTapped(_ sender: UIButton) {
        guard
            let index = buttons.firstIndex(of: sender),
            index < periods.count
        else { return }

        let period = periods[index]
        selectedPeriod = period

        delegate?.periodControl(
            self,
            didSelect: period
        )

        buttons.forEach { updateButton($0, isSelected: $0 == sender) }
        updateSelectionBackground(animated: true)
    }
}

// MARK: Constants

private extension PriceChartPeriodControl {
    enum Constants {
        static let stackSpacing: CGFloat = 12.0
        static let cornerRadius: CGFloat = 8.0

        static let stackInsets = UIEdgeInsets(
            top: 8,
            left: 16,
            bottom: 8,
            right: 16
        )
        static let buttonSize = CGSize(
            width: 41,
            height: 32
        )
        static let selectedBackgroundSize = CGSize(
            width: 41,
            height: 24
        )

        static let animationScale: CGFloat = 0.85
    }
}
