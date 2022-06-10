import Foundation
import UIKit

struct AccountDetailsSelectionViewModel {
    let displayAddress: DisplayAddressViewModel
    let details: TitleWithSubtitleViewModel?
}

final class AccountDetailsSelectionView: UIView {
    let iconView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private(set) var detailsLabel: UILabel?

    let disclosureIndicatorView: UIView = {
        let imageView = UIImageView()
        let icon = R.image.iconSmallArrow()?.tinted(with: R.color.colorTransparentText()!)
        imageView.image = icon
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return imageView
    }()

    var showsDisclosureIndicator: Bool {
        get {
            !disclosureIndicatorView.isHidden
        }

        set {
            disclosureIndicatorView.isHidden = !newValue
        }
    }

    private var viewModel: AccountDetailsSelectionViewModel?

    override var intrinsicContentSize: CGSize {
        let imageHeight = UIConstants.address24IconSize.height

        var labelsHeight = titleLabel.intrinsicContentSize.height

        if let detailsLabel = detailsLabel {
            labelsHeight += detailsLabel.intrinsicContentSize.height
        }

        let height = max(imageHeight, labelsHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AccountDetailsSelectionViewModel) {
        bind(viewModel: viewModel, enabled: true)
    }

    func bind(viewModel: AccountDetailsSelectionViewModel, enabled: Bool) {
        self.viewModel?.displayAddress.imageViewModel?.cancel(on: iconView)

        self.viewModel = viewModel

        if let imageViewModel = viewModel.displayAddress.imageViewModel {
            imageViewModel.loadImage(
                on: iconView,
                targetSize: UIConstants.address24IconSize,
                animated: true
            )
        } else {
            iconView.image = R.image.iconAddressPlaceholder()
        }

        if let name = viewModel.displayAddress.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.displayAddress.address
        }

        titleLabel.textColor = enabled ? R.color.colorWhite()! : R.color.colorWhite32()!
        iconView.alpha = enabled ? 1.0 : 0.5

        if let details = viewModel.details {
            setupDetailsLabelIfNeeded()
            applyDetails(details, enabled: enabled)
        } else {
            clearDetailsLabelIfNeeded()
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setupDetailsLabelIfNeeded() {
        guard detailsLabel == nil else {
            return
        }

        let detailsLabel = UILabel()
        detailsLabel.font = .caption1

        addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.equalTo(disclosureIndicatorView.snp.leading).offset(-8)
            make.bottom.equalToSuperview()
        }

        titleLabel.snp.remakeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.equalTo(disclosureIndicatorView.snp.leading).offset(-8)
            make.top.equalToSuperview()
        }

        titleLabel.font = .regularFootnote

        self.detailsLabel = detailsLabel
    }

    private func clearDetailsLabelIfNeeded() {
        guard detailsLabel != nil else {
            return
        }

        detailsLabel?.removeFromSuperview()
        detailsLabel = nil

        titleLabel.snp.remakeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.equalTo(disclosureIndicatorView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }

        titleLabel.font = .regularSubheadline
    }

    private func applyDetails(_ details: TitleWithSubtitleViewModel, enabled: Bool) {
        let titleColor = enabled ? R.color.colorTransparentText()! : R.color.colorWhite32()!

        let attributedString = NSMutableAttributedString(
            string: details.title,
            attributes: [
                .foregroundColor: titleColor
            ]
        )

        let subtitleColor = enabled ? R.color.colorWhite()! : R.color.colorWhite32()!

        let subtitleAttributedString = NSAttributedString(
            string: " " + details.subtitle,
            attributes: [
                .foregroundColor: subtitleColor
            ]
        )

        attributedString.append(subtitleAttributedString)

        detailsLabel?.attributedText = attributedString
    }

    private func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(UIConstants.address24IconSize)
        }

        addSubview(disclosureIndicatorView)
        disclosureIndicatorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.equalTo(disclosureIndicatorView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
    }
}
