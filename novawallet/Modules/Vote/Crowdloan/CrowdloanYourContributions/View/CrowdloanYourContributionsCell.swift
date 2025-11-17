import UIKit

final class CrowdloanYourContributionsCell: UITableViewCell {
    private(set) var model: CrowdloanContributionViewModel?

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var iconViewModel: ImageViewModelProtocol?

    private let nameDetailsView: MultiValueView = {
        let view = MultiValueView()
        view.apply(style: .contributionReturnsIn)
        view.valueTop.textAlignment = .left
        view.valueBottom.textAlignment = .left
        return view
    }()

    private let contributedAmountView: MultiValueView = {
        let view = MultiValueView()
        view.apply(style: .contributionReturnsIn)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        iconViewModel?.cancel(on: iconImageView)
        iconViewModel = nil
        iconImageView.image = nil
    }

    private func setupLayout() {
        let content = UIView.hStack(
            alignment: .center,
            spacing: 12,
            [
                iconImageView, nameDetailsView, UIView(), contributedAmountView
            ]
        )
        iconImageView.snp.makeConstraints { $0.size.equalTo(32) }

        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(8)
        }
    }

    func bind(contributionViewModel: CrowdloanContributionViewModel) {
        nameDetailsView.bind(topValue: contributionViewModel.name, bottomValue: nameDetailsView.valueBottom.text)
        contributedAmountView.bind(
            topValue: contributionViewModel.contributed.amount,
            bottomValue: contributionViewModel.contributed.price
        )

        iconViewModel?.cancel(on: iconImageView)
        iconViewModel = contributionViewModel.iconViewModel

        contributionViewModel.iconViewModel?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true
        )

        model = contributionViewModel
    }

    func bind(unlockViewModel: String, style: UnlockStyle) {
        switch style {
        case .claimable:
            nameDetailsView.apply(style: .contributionClamable)
        case .returnIn:
            nameDetailsView.apply(style: .contributionReturnsIn)
        }

        nameDetailsView.bind(topValue: nameDetailsView.valueTop.text ?? "", bottomValue: unlockViewModel)
    }
}

extension CrowdloanYourContributionsCell {
    enum UnlockStyle {
        case claimable
        case returnIn
    }
}
