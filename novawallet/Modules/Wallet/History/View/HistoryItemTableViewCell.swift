import Foundation
import SnapKit
import CommonWallet
import UIKit

final class HistoryItemTableViewCell: UITableViewCell {
    private enum Constants {
        static let verticalInset: CGFloat = 11
        static let iconSize = CGSize(width: 36, height: 36)
        static let imageInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        static let statusOffset: CGFloat = 4.0
        static let titleSpacingForTransfer: CGFloat = 64.0
        static let titleSpacingForOthers: CGFloat = 8.0

        static var displayImageSize: CGSize {
            CGSize(
                width: iconSize.width - imageInsets.left - imageInsets.right,
                height: iconSize.height - imageInsets.top - imageInsets.bottom
            )
        }
    }

    let iconView: AssetIconView = {
        let view = AssetIconView()
        view.backgroundView.cornerRadius = Constants.iconSize.height / 2.0
        view.backgroundView.fillColor = R.color.colorWhite16()!
        view.backgroundView.highlightedFillColor = R.color.colorWhite16()!
        view.backgroundView.strokeColor = R.color.colorWhite8()!
        view.contentInsets = Constants.imageInsets
        view.imageView.tintColor = R.color.colorTransparentText()
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite48()
        return label
    }()

    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite48()
        return label
    }()

    private var statusImageView: UIImageView?

    var viewModel: WalletViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorHighlightedAccent()!

        setupLayout()
    }

    private func setupLayout() {
        contentView.addSubview(iconView)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        contentView.addSubview(amountLabel)

        amountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.top.equalToSuperview().inset(Constants.verticalInset)
            make.trailing.lessThanOrEqualTo(amountLabel.snp.leading)
                .offset(-Constants.titleSpacingForTransfer)
        }

        contentView.addSubview(timeLabel)

        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(amountLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
        }

        contentView.addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.top.equalTo(titleLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading)
                .offset(-UIConstants.horizontalInset)
        }
    }

    private func addStatusViewIfNeeded() {
        guard statusImageView == nil else {
            return
        }

        let statusImageView = UIImageView()
        contentView.addSubview(statusImageView)

        statusImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(amountLabel)
        }

        self.statusImageView = statusImageView
    }

    private func removeStatusView() {
        guard statusImageView != nil else {
            return
        }

        statusImageView?.removeFromSuperview()
        statusImageView = nil
    }

    private func updateAmountConstraints() {
        amountLabel.snp.updateConstraints { make in
            if let statusSize = statusImageView?.image?.size {
                let inset = UIConstants.horizontalInset + statusSize.width + Constants.statusOffset
                make.trailing.equalToSuperview().inset(inset)
            } else {
                make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            }
        }
    }
}

extension HistoryItemTableViewCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let itemViewModel = viewModel as? HistoryItemViewModel {
            self.viewModel = viewModel

            titleLabel.text = itemViewModel.title
            subtitleLabel.text = itemViewModel.subtitle
            timeLabel.text = itemViewModel.time

            switch itemViewModel.type {
            case .incoming, .reward:
                amountLabel.text = "+ \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorGreen()!
            case .outgoing, .slash, .extrinsic:
                amountLabel.text = "- \(itemViewModel.amount)"
                amountLabel.textColor = R.color.colorWhite()!
            }

            switch itemViewModel.type {
            case .incoming, .outgoing:
                titleLabel.lineBreakMode = .byTruncatingMiddle

                titleLabel.snp.updateConstraints { make in
                    make.trailing.lessThanOrEqualTo(amountLabel.snp.leading)
                        .offset(-Constants.titleSpacingForTransfer)
                }

            case .slash, .reward, .extrinsic:
                titleLabel.lineBreakMode = .byTruncatingTail

                titleLabel.snp.updateConstraints { make in
                    make.trailing.lessThanOrEqualTo(amountLabel.snp.leading)
                        .offset(-Constants.titleSpacingForOthers)
                }
            }

            switch itemViewModel.status {
            case .commited:
                removeStatusView()
            case .rejected:
                addStatusViewIfNeeded()
                statusImageView?.image = R.image.iconErrorFilled()
                amountLabel.textColor = R.color.colorTransparentText()
            case .pending:
                addStatusViewIfNeeded()
                statusImageView?.image = R.image.iconPending()
                amountLabel.textColor = R.color.colorWhite()
            }

            let settings = ImageViewModelSettings(
                targetSize: Constants.displayImageSize,
                cornerRadius: nil,
                tintColor: R.color.colorTransparentText()
            )

            iconView.bind(viewModel: itemViewModel.imageViewModel, settings: settings)

            updateAmountConstraints()

            setNeedsLayout()
        }
    }
}
