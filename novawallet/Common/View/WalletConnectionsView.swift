import SnapKit
import UIKit
import UIKit_iOS

final class WalletConnectionsView: UIView {
    let iconView: UIImageView = .create {
        $0.image = R.image.iconWalletConnect()?.tinted(with: R.color.colorIconChip()!)
    }

    let iconBackground: RoundedView = .create {
        $0.cornerRadius = Constants.iconSize.width
        $0.apply(style: .clear)
        $0.fillColor = R.color.colorButtonWalletConnectBackground()!
        $0.highlightedFillColor = R.color.colorButtonWalletConnectBackground()!
    }

    let connectionsBackground: RoundedView = .create {
        $0.roundingCorners = .allCorners
        $0.cornerRadius = Constants.iconSize.width
        $0.apply(style: .clear)
        $0.fillColor = R.color.colorWalletConnectionsBackground()!
        $0.highlightedFillColor = R.color.colorWalletConnectionsBackground()!
    }

    let connectionsView: IconDetailsView = .create {
        $0.mode = .iconDetails
        $0.detailsLabel.apply(style: .semiboldChip)
        $0.iconWidth = Constants.connectionsIconWidth
        $0.imageView.image = R.image.iconConnections()
        $0.spacing = Constants.сonnectionsIconTextSpacing
        $0.isHidden = true
    }

    private var connectionsWidthConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(connectionsBackground)
        connectionsBackground.addSubview(connectionsView)
        addSubview(iconBackground)
        iconBackground.addSubview(iconView)

        connectionsBackground.snp.makeConstraints {
            $0.height.equalTo(Constants.height)
            $0.trailing.equalTo(connectionsView.snp.trailing).offset(
                Constants.connectionsTextTrailingOffset).priority(.high)
            $0.leading.centerY.equalToSuperview()
            connectionsWidthConstraint = $0.width.equalTo(iconBackground.snp.width).constraint
        }

        connectionsView.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalTo(iconBackground.snp.trailing).offset(
                Constants.iconAndConnectionsSpacing)
        }

        iconBackground.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
            $0.size.equalTo(Constants.iconSize)
        }

        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }
}

extension WalletConnectionsView {
    enum Model {
        case empty
        case activeConections(String)
    }

    func bind(model: Model, animated: Bool) {
        var connectionsViewHidden: Bool
        switch model {
        case .empty:
            connectionsViewHidden = true
            connectionsView.detailsLabel.text = nil
            connectionsWidthConstraint?.activate()
        case let .activeConections(count):
            connectionsViewHidden = false
            connectionsView.detailsLabel.text = count
            connectionsWidthConstraint?.deactivate()
        }

        setNeedsLayout()

        UIView.animate(withDuration: animated ? 0.2 : 0, animations: {
            self.connectionsView.alpha = connectionsViewHidden ? 0 : 1
            self.layoutIfNeeded()
        }, completion: { completed in
            if completed {
                self.connectionsView.isHidden = connectionsViewHidden
            }
        })
    }
}

extension WalletConnectionsView {
    enum Constants {
        static let iconSize = CGSize(width: 40, height: 40)
        static let height: CGFloat = 40
        static let connectionsIconWidth: CGFloat = 14
        static let connectionsTextTrailingOffset: CGFloat = 16
        static let сonnectionsIconTextSpacing: CGFloat = 4
        static let iconAndConnectionsSpacing: CGFloat = 8
    }
}
