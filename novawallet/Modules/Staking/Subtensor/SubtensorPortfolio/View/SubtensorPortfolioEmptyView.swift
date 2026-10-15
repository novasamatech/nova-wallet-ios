import UIKit

final class SubtensorPortfolioEmptyView: UIView {
    let captionLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
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

    func bind(viewModel: SubtensorPortfolioEmptyViewModel) {
        totalLabel.text = viewModel.total
        fiatLabel.text = viewModel.fiat
        fiatLabel.isHidden = viewModel.fiat == nil
        rootCardView.subtitleLabel.text = viewModel.rootSubtitle
    }
}

private extension SubtensorPortfolioEmptyView {
    func setupLayout() {
        let headerContentView = UIView.vStack(alignment: .center, spacing: 4, [captionLabel, totalLabel, fiatLabel])

        let headerView = UIView()
        headerView.backgroundColor = R.color.colorBlockBackground()
        headerView.layer.cornerRadius = 12
        headerView.addSubview(headerContentView)

        headerContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16))
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

        let contentView = UIView.vStack(spacing: 2, [titleLabel, subtitleLabel])

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
