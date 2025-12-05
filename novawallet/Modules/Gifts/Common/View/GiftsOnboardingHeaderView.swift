import Foundation
import UIKit

final class GiftsListHeaderTableViewCell: CollectionViewContainerCell<GiftsListHeaderView> {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    func bind(locale: Locale) {
        view.locale = locale
    }
}

final class GiftsListHeaderView: GenericPairValueView<MultiValueView, LinkView> {
    private var titleLabel: UILabel {
        fView.valueTop
    }

    private var subtitleLabel: UILabel {
        fView.valueBottom
    }

    private var learnMoreText: String? {
        get { learnMoreView.actionButton.imageWithTitleView?.title }
        set { learnMoreView.actionButton.imageWithTitleView?.title = newValue }
    }

    var locale: Locale = .current {
        didSet {
            updateLocalization()
        }
    }

    var learnMoreView: LinkView {
        sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }
}

// MARK: - Private

private extension GiftsListHeaderView {
    func setupLayout() {
        makeVertical()

        fView.spacing = Constants.titleSubtitleSpacing
        spacing = Constants.headerLearnMoreSpacing

        stackView.alignment = .leading
        learnMoreView.mode = .iconDetails
        learnMoreView.actionButton.contentInsets = Constants.learnMoreContentInsets
    }

    func setupStyle() {
        titleLabel.apply(style: .boldTitle1Primary)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .left

        subtitleLabel.apply(style: .regularSubhedlineSecondary)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .left
    }

    func updateLocalization() {
        let languages = locale.rLanguages

        titleLabel.text = R.string(preferredLanguages: languages).localizable.giftsOnboardingTitle()
        subtitleLabel.text = R.string(preferredLanguages: languages).localizable.giftsOnboardingSubtitle()
        learnMoreText = R.string(preferredLanguages: languages).localizable.commonLearnMore()
    }
}

// MARK: - Constants

private extension GiftsListHeaderView {
    enum Constants {
        static let titleSubtitleSpacing: CGFloat = 8
        static let headerLearnMoreSpacing: CGFloat = 4
        static let learnMoreContentInsets = UIEdgeInsets(top: 8.0, left: 0, bottom: 8.0, right: 0)
    }
}
