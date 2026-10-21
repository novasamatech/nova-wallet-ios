import UIKit

final class SubtensorPortfolioEmptyView: UIView {
    let captionLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
        label.textAlignment = .center
    }

    let totalLabel: UILabel = .create { label in
        label.apply(style: .boldTitle1Primary)
        label.textAlignment = .center
    }

    let fiatLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
        label.textAlignment = .center
    }

    let subnetCardView = SubtensorPortfolioInfoCardView()
    let rootCardView = SubtensorPortfolioInfoCardView()
    let unstakeCardView = SubtensorPortfolioInfoCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(caption: String) {
        captionLabel.apply(text: caption, lineHeight: Constants.subheadlineLineHeight)
    }

    func bind(viewModel: SubtensorPortfolioEmptyViewModel) {
        totalLabel.text = viewModel.total
        fiatLabel.apply(text: viewModel.fiat ?? "", lineHeight: Constants.subheadlineLineHeight)
        fiatLabel.isHidden = viewModel.fiat == nil
        rootCardView.bind(subtitle: viewModel.rootSubtitle)
    }
}

private extension SubtensorPortfolioEmptyView {
    func setupLayout() {
        let headerContentView = UIView.vStack(alignment: .center, spacing: 0, [captionLabel, totalLabel, fiatLabel])
        headerContentView.setCustomSpacing(Constants.captionSpacing, after: captionLabel)
        headerContentView.setCustomSpacing(Constants.totalSpacing, after: totalLabel)

        let headerView = UIView()
        headerView.backgroundColor = R.color.colorBlockBackground()
        headerView.layer.cornerRadius = 12
        headerView.addSubview(headerContentView)

        headerContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.headerInsets)
        }

        let contentView = UIView.vStack(
            spacing: 8,
            [headerView, subnetCardView, rootCardView, unstakeCardView]
        )

        contentView.setCustomSpacing(16, after: headerView)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    enum Constants {
        static let headerInsets = UIEdgeInsets(top: 16, left: 16, bottom: 18, right: 16)
        static let captionSpacing: CGFloat = 6
        static let totalSpacing: CGFloat = 7
        static let subheadlineLineHeight: CGFloat = 20
    }
}

final class SubtensorPortfolioInfoCardView: UIView {
    let titleLabel: UILabel = .create { label in
        label.apply(style: .regularBodyPrimary)
        label.numberOfLines = 0
    }

    let subtitleLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12

        let contentView = UIView.vStack(spacing: Constants.spacing, [titleLabel, subtitleLabel])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String) {
        titleLabel.apply(text: title, lineHeight: Constants.titleLineHeight)
    }

    func bind(subtitle: String?) {
        subtitleLabel.apply(text: subtitle ?? "", lineHeight: Constants.subtitleLineHeight)
    }
}

private extension SubtensorPortfolioInfoCardView {
    enum Constants {
        static let spacing: CGFloat = 4
        static let titleLineHeight: CGFloat = 22
        static let subtitleLineHeight: CGFloat = 16
    }
}
