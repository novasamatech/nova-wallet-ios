import Foundation
import UIKit
import UIKit_iOS

protocol SignatoryListExpandableViewDelegate: AnyObject {
    func didChangeState(to state: SignatoryListExpandableView.State)
}

final class SignatoryListExpandableView: UIView {
    weak var delegate: SignatoryListExpandableViewDelegate?
    var state: State = .collapsed(Constants.collapsedStateHeight)

    private let appearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0,
        duration: 0.15
    )
    private let disappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: 0.15
    )
    private let arrowTransformAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.2,
        options: [.curveEaseOut]
    )

    private let signatoryTableView = StackSignatoryCheckmarkTableView()

    private let headerCell: StackTitleIconDetailsCell = .create { view in
        view.titleLabel.apply(style: .footnoteSecondary)
        view.valueLabel.apply(style: .footnoteSecondary)
        view.contentInsets = Constants.headerCellInsets
        view.iconView.image = R.image.iconSmallArrowDown()?.tinted(
            with: R.color.colorIconSecondary()!
        )
    }

    private var locale: Locale? {
        didSet {
            updateActionText(for: state)
        }
    }

    var rowIconImageView: UIImageView {
        headerCell.rowContentView.sView.imageView
    }

    var titleLabel: UILabel {
        headerCell.titleLabel
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
        setupActions()
        hideDetails()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension SignatoryListExpandableView {
    func setupLayout() {
        addSubview(signatoryTableView)
        signatoryTableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupSignatoryTableViewLayout()
    }

    func setupStyle() {
        clipsToBounds = true
        headerCell.roundedBackgroundView.highlightedFillColor = .clear
    }

    func setupSignatoryTableViewLayout() {
        signatoryTableView.tableView.addArrangedSubview(headerCell)

        headerCell.snp.makeConstraints { make in
            make.height.equalTo(Constants.headerCellHeight)
        }
        rowIconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.arrowImageViewSize)
        }
    }

    func setupActions() {
        headerCell.addTarget(
            self,
            action: #selector(actionToggleState),
            for: .touchUpInside
        )
    }

    func hideDetails(animated: Bool = false) {
        signatoryTableView.rows.forEach {
            if animated {
                disappearanceAnimator.animate(view: $0, completionBlock: nil)
            } else {
                $0.alpha = 0
            }
        }
    }

    func showDetails(animated: Bool = false) {
        signatoryTableView.rows.forEach {
            if animated {
                appearanceAnimator.animate(view: $0, completionBlock: nil)
            } else {
                $0.alpha = 1
            }
        }
    }

    func toggleState() {
        let arrowIconTransform: CGAffineTransform

        switch state {
        case .collapsed:
            state = .expanded(calculateExpandedHeight())
            arrowIconTransform = CGAffineTransform(rotationAngle: .pi)
            showDetails(animated: true)
        case .expanded:
            state = .collapsed(Constants.collapsedStateHeight)
            arrowIconTransform = .identity
            hideDetails(animated: true)
        }

        updateActionText(for: state)

        arrowTransformAnimator.animate(
            block: { [weak self] in
                self?.rowIconImageView.transform = arrowIconTransform
            },
            completionBlock: nil
        )

        delegate?.didChangeState(to: state)
    }

    func calculateExpandedHeight() -> CGFloat {
        let contentHeight = CGFloat(signatoryTableView.rows.count)
            * StackSignatoryCheckmarkTableView.Constants.signatoryCellHeight
        let totalHeight = Constants.headerCellHeight
            + contentHeight
            + StackSignatoryCheckmarkTableView.Constants.contentInsets.top
            + StackSignatoryCheckmarkTableView.Constants.contentInsets.bottom

        return totalHeight
    }

    func updateActionText(for state: State) {
        guard let locale else { return }

        switch state {
        case .collapsed:
            headerCell.valueLabel.text = R.string.localizable.commonShow(
                preferredLanguages: locale.rLanguages
            )
        case .expanded:
            headerCell.valueLabel.text = R.string.localizable.commonHide(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    @objc func actionToggleState() {
        toggleState()
    }
}

// MARK: Internal

extension SignatoryListExpandableView {
    func bind(with model: SignatoryListViewModel) {
        signatoryTableView.tableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        signatoryTableView.tableView.addArrangedSubview(headerCell)
        signatoryTableView.bind(with: model)
    }

    func set(locale: Locale) {
        self.locale = locale
    }
}

// MARK: State

extension SignatoryListExpandableView {
    enum State {
        case expanded(CGFloat)
        case collapsed(CGFloat)

        var height: CGFloat {
            switch self {
            case let .collapsed(value), let .expanded(value):
                return value
            }
        }
    }
}

// MARK: Constants

extension SignatoryListExpandableView {
    enum Constants {
        static let headerCellHeight: CGFloat = 44.0
        static let collapsedStateHeight: CGFloat = 52.0
        static let arrowImageViewSize: CGSize = .init(width: 24, height: 24)

        static let headerCellInsets: UIEdgeInsets = .init(
            top: 14,
            left: 16,
            bottom: 0,
            right: 16
        )
    }
}
