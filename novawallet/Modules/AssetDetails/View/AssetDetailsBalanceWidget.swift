import Foundation
import UIKit
import SoraUI

protocol AssetDetailsBalanceWidgetDelegate: AnyObject {
    func didChangeState(to state: AssetDetailsBalanceWidget.State)
}

class AssetDetailsBalanceWidget: UIView {
    weak var delegate: AssetDetailsBalanceWidgetDelegate?

    var state: State = .collapsed(Constants.collapsedStateHeight)

    private let balanceTableView: StackTableView = .create {
        $0.cellHeight = Constants.balanceCellHeight
        $0.setCustomHeight(52.0, at: 1)
        $0.setShowsSeparator(false, at: 1)
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }

    let headerCell: StackTableHeaderCell = .create {
        $0.titleLabel.apply(style: .regularSubhedlineSecondary)
        $0.contentInsets = .init(top: 14, left: 16, bottom: 14, right: 16)
    }

    let totalCell: StackTitleValueIconView = .create { view in
        view.frame = CGRect(
            origin: view.frame.origin,
            size: CGSize(width: view.frame.width, height: 52)
        )
    }

    let transferrableCell: StackTitleMultiValueCell = .create {
        $0.apply(style: .balancePart)
        $0.canSelect = false
    }

    let lockCell: StackTitleMultiValueCell = .create {
        $0.apply(style: .balancePart)
        $0.canSelect = false
    }

    var totalTokensBalanceLabel: UILabel {
        totalCell.rowContentView.fView.detailsLabel
    }

    var totalValueBalanceLabel: UILabel {
        totalCell.rowContentView.sView
    }

    let appearanceAnimator: ViewAnimatorProtocol = FadeAnimator(from: 0.0, to: 1.0)
    let disappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(from: 1.0, to: 0.0)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupActions()
        hideDetails()
        clipsToBounds = true
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

    func setupBalanceTableViewLayout() {
        balanceTableView.addArrangedSubview(headerCell)
        balanceTableView.addArrangedSubview(totalCell)
        balanceTableView.addArrangedSubview(transferrableCell)
        balanceTableView.addArrangedSubview(lockCell)

        headerCell.snp.makeConstraints { make in
            make.height.equalTo(44.0)
        }

        totalCell.snp.makeConstraints { make in
            make.height.equalTo(52.0)
        }
    }

    func setupActions() {
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(actionTap)
        )

        totalCell.addGestureRecognizer(tapGesture)
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
        switch state {
        case .collapsed:
            state = .expanded(Constants.expandedStateHeight)
            showDetails(animated: true)
        case .expanded:
            state = .collapsed(Constants.collapsedStateHeight)
            hideDetails(animated: true)
        }

        delegate?.didChangeState(to: state)
    }

    @objc func actionTap() {
        toggleState()
    }
}

// MARK: Internal

extension AssetDetailsBalanceWidget {
    func set(locale: Locale) {
        let languages = locale.rLanguages

        headerCell.titleLabel.text = R.string.localizable.walletBalancesWidgetTitle(
            preferredLanguages: languages
        )
        transferrableCell.titleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: languages
        )
        lockCell.titleLabel.text = R.string.localizable.walletBalanceLocked(
            preferredLanguages: languages
        )
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
        static let balanceCellHeight: CGFloat = 48
        static let collapsedStateHeight: CGFloat = 112.0
        static let expandedStateHeight: CGFloat = 204.0
    }
}
