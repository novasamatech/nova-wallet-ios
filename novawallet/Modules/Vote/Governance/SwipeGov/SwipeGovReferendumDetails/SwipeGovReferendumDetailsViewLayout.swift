import UIKit

final class SwipeGovReferendumDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 6.0, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .leading
        return view
    }()

    var accountIconSize: CGSize {
        let size = accountContainerView.rowContentView.detailsView.iconWidth
        return CGSize(width: size, height: size)
    }

    let timeView: IconDetailsView = .create {
        $0.mode = .detailsIcon
        $0.detailsLabel.numberOfLines = 1
        $0.spacing = 5
        $0.apply(style: .timeView)
    }

    let shareButton = UIBarButtonItem(
        image: R.image.iconShare(),
        style: .plain,
        target: nil,
        action: nil
    )

    var accountLabel: UILabel { accountContainerView.rowContentView.detailsView.detailsLabel }
    var accountImageView: UIImageView { accountContainerView.rowContentView.detailsView.imageView }

    let accountContainerView: RowView<IconDetailsGenericView<IconDetailsView>> = .create { view in
        view.roundedBackgroundView.highlightedFillColor = .clear
        view.changesContentOpacityWhenHighlighted = true
        view.borderView.borderType = .none

        view.preferredHeight = 36.0
        view.rowContentView.mode = .detailsIcon
        view.rowContentView.iconWidth = 16.0
        view.rowContentView.spacing = 6
        view.contentInsets = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)
        view.rowContentView.imageView.image = R.image.iconInfoFilled()

        let addressView = view.rowContentView.detailsView
        addressView.spacing = 7
        addressView.detailsLabel.numberOfLines = 1
        addressView.detailsLabel.apply(style: .footnoteSecondary)
        addressView.iconWidth = 18.0
    }

    private var addressImageViewModel: ImageViewModelProtocol?

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorTextPrimary()
        $0.font = .boldTitle1
        $0.numberOfLines = 0
    }

    let descriptionView = MarkdownViewContainer(
        preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset
    )

    let trackTagsView = TrackTagsView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)

        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(accountContainerView)
        containerView.stackView.setCustomSpacing(0, after: accountContainerView)

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(8, after: titleLabel)

        containerView.stackView.addArrangedSubview(descriptionView)
        containerView.stackView.setCustomSpacing(8, after: descriptionView)
    }
}

extension SwipeGovReferendumDetailsViewLayout {
    func bind(viewModel: ReferendumDetailsTitleView.Model, locale: Locale) {
        addressImageViewModel?.cancel(on: accountImageView)
        addressImageViewModel = viewModel.account?.imageViewModel

        if let account = viewModel.account {
            accountContainerView.isHidden = false

            accountLabel.text = account.name ?? account.address.truncated

            account.imageViewModel?.loadImage(
                on: accountImageView,
                targetSize: accountIconSize,
                animated: true
            )

        } else {
            accountContainerView.isHidden = true
        }

        bind(details: viewModel.details, locale: locale)
    }

    func bind(trackTagsModel: TrackTagsView.Model?) {
        guard
            let trackTagsModel,
            trackTagsView.superview == nil
        else {
            return
        }

        containerView.stackView.insertArranged(
            view: trackTagsView,
            after: titleLabel
        )
        containerView.stackView.setCustomSpacing(8.0, after: trackTagsView)

        trackTagsView.bind(viewModel: trackTagsModel)
    }

    private func bind(details: ReferendumDetailsTitleView.Details?, locale _: Locale) {
        guard let details = details else {
            titleLabel.isHidden = true
            descriptionView.isHidden = true
            return
        }
        titleLabel.isHidden = false
        titleLabel.text = details.title

        descriptionView.isHidden = false
        descriptionView.load(from: details.description) { _ in }
    }
}
