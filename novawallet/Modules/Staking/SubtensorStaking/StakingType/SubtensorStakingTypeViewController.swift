import UIKit
import Foundation_iOS

/// Simple selection screen: Root staking vs Subnet staking.
/// Matches the visual language of Nova's Pool/Direct type picker
/// but is self-contained — no interactor, no async data. The user
/// taps a card and presses Continue.
final class SubtensorStakingTypeViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorStakingTypeViewLayout

    enum Selection {
        case root
        case subnet
    }

    private let chainAsset: ChainAsset
    private let onSelection: (Selection) -> Void
    private var currentSelection: Selection = .root

    init(
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        onSelection: @escaping (Selection) -> Void
    ) {
        self.chainAsset = chainAsset
        self.onSelection = onSelection
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorStakingTypeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        applySelection(.root)
    }

    // MARK: - Localization

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages)
            .localizable.stakingTypeTitle()

        rootView.rootBanner.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorTypeRoot()

        rootView.rootBanner.detailsLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorTypeRootDetails()

        rootView.subnetBanner.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorTypeSubnet()

        rootView.subnetBanner.detailsLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorTypeSubnetDetails()

        rootView.continueButton.imageWithTitleView?.title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.commonContinue()

        let linkText = R.string(preferredLanguages: selectedLocale.rLanguages)
            .localizable.stakingSubtensorTypeWikiLink()
        let fullText = R.string(preferredLanguages: selectedLocale.rLanguages)
            .localizable.stakingSubtensorTypeWikiFooter(linkText)

        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .foregroundColor: R.color.colorTextSecondary()!,
                .font: UIFont.regularFootnote
            ]
        )
        if let linkRange = (fullText as NSString).range(of: linkText) as NSRange?,
           linkRange.location != NSNotFound {
            attributed.addAttributes(
                [
                    .foregroundColor: R.color.colorButtonTextAccent()!,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ],
                range: linkRange
            )
        }
        // TODO(wiki): when the Nova Wiki page for Bittensor staking is published,
        // make "Nova Wiki" tappable. Two options: (1) swap UILabel for UITextView
        // with `.link` attribute + delegate handler, or (2) keep UILabel and add
        // a UITapGestureRecognizer that hit-tests `linkRange` via UILabel layout
        // manager. URL likely lands in `applicationConfig` or as a chain
        // `additional.stakingWiki` value alongside the other chains.
        rootView.wikiLabel.attributedText = attributed
    }

    // MARK: - Handlers

    private func setupHandlers() {
        let rootTap = UITapGestureRecognizer(target: self, action: #selector(rootBannerTapped))
        rootView.rootBanner.addGestureRecognizer(rootTap)

        let subnetTap = UITapGestureRecognizer(target: self, action: #selector(subnetBannerTapped))
        rootView.subnetBanner.addGestureRecognizer(subnetTap)

        rootView.continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    @objc private func rootBannerTapped() {
        applySelection(.root)
    }

    @objc private func subnetBannerTapped() {
        applySelection(.subnet)
    }

    @objc private func continueTapped() {
        onSelection(currentSelection)
    }

    // MARK: - Selection state

    private func applySelection(_ selection: Selection) {
        currentSelection = selection

        switch selection {
        case .root:
            rootView.rootBanner.borderView.isHighlighted = true
            rootView.rootBanner.radioSelectorView.selected = true
            rootView.subnetBanner.borderView.isHighlighted = false
            rootView.subnetBanner.radioSelectorView.selected = false
        case .subnet:
            rootView.rootBanner.borderView.isHighlighted = false
            rootView.rootBanner.radioSelectorView.selected = false
            rootView.subnetBanner.borderView.isHighlighted = true
            rootView.subnetBanner.radioSelectorView.selected = true
        }
    }
}

// MARK: - Localizable

extension SubtensorStakingTypeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
