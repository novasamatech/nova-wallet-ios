import UIKit
import SoraUI

protocol StackTableViewCellProtocol: UIView {
    var borderView: BorderedContainerView { get }
    var contentInsets: UIEdgeInsets { get set }
    var preferredHeight: CGFloat? { get set }
    var roundedBackgroundView: RoundedView! { get }
}

final class StackTableView: RoundedView {
    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        return view
    }()

    var contentInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0) {
        didSet {
            if oldValue != contentInsets {
                updateLayout()
            }
        }
    }

    var cellHeight: CGFloat = 44.0 {
        didSet {
            if oldValue != cellHeight {
                updateLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addArrangedSubview(_ view: StackTableViewCellProtocol) {
        stackView.addArrangedSubview(view)
        updateLayout()
    }

    func insertArrangedSubview(_ view: StackTableViewCellProtocol, at index: Int) {
        stackView.insertSubview(view, at: index)
        updateLayout()
    }

    func insertArranged(view: StackTableViewCellProtocol, after subview: UIView) {
        stackView.insertArranged(view: view, after: subview)
        updateLayout()
    }

    func insertArranged(view: StackTableViewCellProtocol, before subview: UIView) {
        stackView.insertArranged(view: view, before: subview)
        updateLayout()
    }

    func updateLayout() {
        let views = stackView.arrangedSubviews

        views.forEach { view in
            guard let rowView = view as? StackTableViewCellProtocol else {
                return
            }

            rowView.preferredHeight = cellHeight
            rowView.borderView.borderType = [.bottom]
            rowView.roundedBackgroundView.cornerRadius = 0.0
            rowView.roundedBackgroundView.roundingCorners = []
        }

        guard
            let lastView = views.last as? StackTableViewCellProtocol,
            let firstView = views.first as? StackTableViewCellProtocol else {
            return
        }

        lastView.borderView.borderType = []

        var lastViewInsets = lastView.contentInsets
        lastViewInsets.bottom = contentInsets.bottom
        lastView.contentInsets = lastViewInsets

        let lastViewHeight = lastView.preferredHeight ?? cellHeight
        lastView.preferredHeight = lastViewHeight + contentInsets.bottom

        lastView.roundedBackgroundView.cornerRadius = cornerRadius

        var lastRoundingCorners = lastView.roundedBackgroundView.roundingCorners
        lastRoundingCorners = lastRoundingCorners.union([.bottomLeft, .bottomRight])
        lastView.roundedBackgroundView.roundingCorners = lastRoundingCorners

        firstView.roundedBackgroundView.cornerRadius = cornerRadius

        var firstViewInsets = firstView.contentInsets
        firstViewInsets.top = contentInsets.top
        firstView.contentInsets = firstViewInsets

        let firstViewHeight = lastView.preferredHeight ?? cellHeight
        firstView.preferredHeight = firstViewHeight + contentInsets.top

        var firstRoundingCorners = firstView.roundedBackgroundView.roundingCorners
        firstRoundingCorners = firstRoundingCorners.union([.topLeft, .topRight])
        firstView.roundedBackgroundView.roundingCorners = firstRoundingCorners

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func configureStyle() {
        applyFilledBackgroundStyle()

        fillColor = R.color.colorWhite8()!
        cornerRadius = 12.0
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
