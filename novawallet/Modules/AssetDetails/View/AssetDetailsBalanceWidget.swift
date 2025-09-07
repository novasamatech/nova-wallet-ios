import Foundation
import UIKit
import UIKit_iOS

protocol AssetDetailsBalanceWidgetDelegate: AnyObject {
    func didChangeState(to state: AssetDetailsBalanceWidget.State)
}

class AssetDetailsBalanceWidget: UIView {
    weak var delegate: AssetDetailsBalanceWidgetDelegate?
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

    private let balanceTableView: StackTableView = .create {
        $0.cellHeight = Constants.balanceCellHeight
        $0.setCustomHeight(Constants.headerCellHeight, at: 0)
        $0.setCustomHeight(Constants.totalCellHeight, at: 1)
        $0.setShowsSeparator(false, at: 1)
        $0.hasSeparators = true
        $0.contentInsets = Constants.contentInsets
    }

    let headerCell: StackTableHeaderCell = .create {
        $0.titleLabel.apply(style: .regularSubhedlineSecondary)
        $0.contentInsets = Constants.headerCellInsets
    }

    let totalCell: StackTitleValueIconView = .create { view in
        view.apply(style: .balanceWidgetStaticPart)
        view.canSelect = false

        view.rowContentView.fView.sView.borderView.cornerRadius = Constants.arrowImageViewSize.width / 2

        view.frame = CGRect(
            origin: view.frame.origin,
            size: CGSize(width: view.frame.width, height: Constants.totalCellHeight)
        )
    }

    let transferrableCell: StackTitleMultiValueCell = .create {
        $0.apply(style: .balancePart)
        $0.canSelect = false
        $0.topValueLabel.adjustsFontSizeToFitWidth = true
        $0.topValueLabel.minimumScaleFactor = 0.5
        $0.bottomValueLabel.adjustsFontSizeToFitWidth = true
        $0.bottomValueLabel.minimumScaleFactor = 0.5
    }

    let lockCell: StackTitleMultiValueCell = .create {
        $0.apply(style: .balancePart)
        $0.canSelect = false
        $0.topValueLabel.adjustsFontSizeToFitWidth = true
        $0.topValueLabel.minimumScaleFactor = 0.5
        $0.bottomValueLabel.adjustsFontSizeToFitWidth = true
        $0.bottomValueLabel.minimumScaleFactor = 0.5
    }

    var rowIconImageView: UIImageView {
        totalCell.rowContentView.fView.sView
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

private extension AssetDetailsBalanceWidget {
    func setupLayout() {
        setupBalanceTableViewLayout()

        addSubview(balanceTableView)
        balanceTableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupStyle() {
        clipsToBounds = true
        totalCell.roundedBackgroundView.highlightedFillColor = .clear
    }

    func setupBalanceTableViewLayout() {
        balanceTableView.addArrangedSubview(headerCell)
        balanceTableView.addArrangedSubview(totalCell)
        balanceTableView.addArrangedSubview(transferrableCell)
        balanceTableView.addArrangedSubview(lockCell)

        headerCell.snp.makeConstraints { make in
            make.height.equalTo(Constants.headerCellHeight)
        }
        totalCell.snp.makeConstraints { make in
            make.height.equalTo(Constants.totalCellHeight)
        }
        rowIconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.arrowImageViewSize)
        }
    }

    func setupActions() {
        totalCell.addTarget(
            self,
            action: #selector(actionToggleState),
            for: .touchUpInside
        )
    }

    func hideDetails(animated: Bool = false) {
        [transferrableCell, lockCell].forEach {
            if animated {
                disappearanceAnimator.animate(view: $0, completionBlock: nil)
            } else {
                $0.alpha = 0
            }
        }
    }

    func showDetails(animated: Bool = false) {
        [transferrableCell, lockCell].forEach {
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
            state = .expanded(Constants.expandedStateHeight)
            arrowIconTransform = CGAffineTransform(rotationAngle: .pi)
            showDetails(animated: true)
        case .expanded:
            state = .collapsed(Constants.collapsedStateHeight)
            arrowIconTransform = .identity
            hideDetails(animated: true)
        }

        arrowTransformAnimator.animate(
            block: { [weak self] in
                self?.rowIconImageView.transform = arrowIconTransform
            },
            completionBlock: nil
        )

        delegate?.didChangeState(to: state)
    }

    @objc func actionToggleState() {
        toggleState()
    }
}

// MARK: Internal

extension AssetDetailsBalanceWidget {
    func bind(with model: AssetDetailsBalanceModel) {
        totalCell.bind(with: model.total.balance)
        totalCell.canSelect = model.total.interactive

        lockCell.bind(viewModel: model.locked.balance)
        lockCell.canSelect = model.locked.interactive

        transferrableCell.bind(viewModel: model.transferrable)
    }

    func set(locale: Locale) {
        let languages = locale.rLanguages

        headerCell.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.walletBalancesWidgetTitle()
        transferrableCell.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.walletBalanceAvailable()
        lockCell.titleLabel.text = R.string(preferredLanguages: languages
        ).localizable.walletBalanceLocked()
    }
}

// MARK: State

extension AssetDetailsBalanceWidget {
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

extension AssetDetailsBalanceWidget {
    enum Constants {
        static let balanceCellHeight: CGFloat = 48.0
        static let headerCellHeight: CGFloat = 44.0
        static let totalCellHeight: CGFloat = 52.0
        static let collapsedStateHeight: CGFloat = 112.0
        static let expandedStateHeight: CGFloat = 204.0
        static let arrowImageViewSize: CGSize = .init(width: 32, height: 32)

        static let headerCellInsets: UIEdgeInsets = .init(
            top: 14,
            left: 16,
            bottom: 0,
            right: 16
        )
        static let contentInsets: UIEdgeInsets = .init(
            top: 0,
            left: 16,
            bottom: 8,
            right: 16
        )
    }
}
