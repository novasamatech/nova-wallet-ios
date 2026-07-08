import UIKit
import UIKit_iOS

final class SubtensorStakingTypeViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        view.stackView.spacing = 16
        return view
    }()

    let rootBanner: SubtensorStakingTypeBannerView = .create {
        $0.imageView.image = R.image.imageStakingTypeDirect()!
    }

    let subnetBanner: SubtensorStakingTypeBannerView = .create {
        $0.imageView.image = R.image.imageStakingTypePool()!
    }

    let wikiLabel: UILabel = {
        let label = UILabel(style: .footnoteSecondary)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(continueButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(rootBanner)
        containerView.stackView.addArrangedSubview(subnetBanner)
        containerView.stackView.addArrangedSubview(wikiLabel)
        containerView.stackView.setCustomSpacing(24, after: subnetBanner)
    }
}

/// Simplified banner card for the Root/Subnet selection screen.
/// Reuses the same visual language as Nova's StakingTypeBaseBannerView
/// (black rounded card, stroke border, radio selector) but without
/// the generic action sub-view or image overlay.
final class SubtensorStakingTypeBannerView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()
        view.cornerRadius = 12
        view.roundingCorners = .allCorners
        view.fillColor = .black
        view.highlightedFillColor = .black
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    let borderView: RoundedView = .create { view in
        view.applyStrokedBackgroundStyle()
        view.cornerRadius = 12
        view.roundingCorners = .allCorners
        view.strokeWidth = 1
        view.strokeColor = R.color.colorStakingTypeCardBorder()!
        view.highlightedStrokeColor = R.color.colorActiveBorder()!
    }

    let radioSelectorView = RadioSelectorView()

    let titleLabel = UILabel(style: .boldTitle2Primary, numberOfLines: 1)

    let detailsLabel: UILabel = {
        let label = UILabel(style: .regularSubhedlineSecondary)
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        backgroundView.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.top.equalToSuperview()
            $0.width.equalTo(140)
            $0.height.equalTo(107)
        }

        addSubview(borderView)
        borderView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let headerStack = UIStackView(arrangedSubviews: [radioSelectorView, titleLabel])
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center

        radioSelectorView.snp.makeConstraints { $0.size.equalTo(24) }

        let contentStack = UIStackView(arrangedSubviews: [headerStack, detailsLabel])
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        addSubview(contentStack)
        contentStack.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}
