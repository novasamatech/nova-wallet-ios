import UIKit
import UIKit_iOS

final class StartStakingInfoSubtensorViewLayout: UIView {
    private let titleStyle = MultiColorTextStyle(
        textColor: R.color.colorTextPrimary()!,
        accentTextColor: R.color.colorButtonTextAccent()!,
        font: .boldTitle1
    )

    let titleLabel: UILabel = .create { label in
        label.textAlignment = .center
        label.numberOfLines = 3
    }

    let earningRows = [
        StartStakingInfoSubtensorRowView(iconTopOffset: 2, showsDivider: true),
        StartStakingInfoSubtensorRowView(iconTopOffset: 24, showsDivider: true),
        StartStakingInfoSubtensorRowView(iconTopOffset: 2, showsDivider: true),
        StartStakingInfoSubtensorRowView(iconTopOffset: 13, showsDivider: false)
    ]

    let primaryButton: RoundedButton = .create { button in
        button.applyPrimaryStyle()
        button.roundedBackgroundView?.cornerRadius = Constants.buttonCornerRadius
        button.imageWithTitleView?.titleFont = .semiBoldSubheadline
    }

    let secondaryButton: RoundedButton = .create { button in
        button.applySecondaryStyle()
        button.roundedBackgroundView?.cornerRadius = Constants.buttonCornerRadius
        button.imageWithTitleView?.titleFont = .semiBoldSubheadline
        button.imageWithTitleView?.titleColor = R.color.colorButtonText()
    }

    let balanceLabel = UILabel(style: .caption1Secondary, textAlignment: .center, numberOfLines: 1)

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.color = R.color.colorIconSecondary()
        view.hidesWhenStopped = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: StartStakingInfoSubtensorViewModel) {
        titleLabel.bind(model: viewModel.title, with: titleStyle)

        for (row, model) in zip(earningRows, viewModel.paragraphs) {
            row.bind(viewModel: model)
        }

        primaryButton.imageWithTitleView?.title = viewModel.primaryActionTitle
        secondaryButton.imageWithTitleView?.title = viewModel.secondaryActionTitle
    }

    func setLoading(_ isLoading: Bool) {
        titleLabel.isHidden = isLoading
        earningRows.forEach { $0.isHidden = isLoading }
        primaryButton.isHidden = isLoading
        secondaryButton.isHidden = isLoading
        balanceLabel.isHidden = isLoading

        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
}

private extension StartStakingInfoSubtensorViewLayout {
    func setupLayout() {
        addSubview(titleLabel)
        earningRows.forEach(addSubview)
        addSubview(primaryButton)
        addSubview(secondaryButton)
        addSubview(balanceLabel)
        addSubview(activityIndicator)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.titleTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.titleHeight)
        }

        earningRows[0].snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.firstRowTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.firstRowHeight)
        }

        earningRows[1].snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.secondRowTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.secondRowHeight)
        }

        earningRows[2].snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.thirdRowTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.thirdRowHeight)
        }

        earningRows[3].snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.fourthRowTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.fourthRowHeight)
        }

        primaryButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.buttonHeight)
        }

        secondaryButton.snp.makeConstraints { make in
            make.top.equalTo(primaryButton.snp.bottom).offset(Constants.actionSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.buttonHeight)
        }

        balanceLabel.snp.makeConstraints { make in
            make.top.equalTo(secondaryButton.snp.bottom).offset(Constants.actionSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.balanceHeight)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(Constants.balanceBottomInset)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}

extension StartStakingInfoSubtensorViewLayout {
    enum Constants {
        static let horizontalInset: CGFloat = 16
        static let titleTopOffset: CGFloat = 24
        static let titleHeight: CGFloat = 84
        static let firstRowTopOffset: CGFloat = 153
        static let firstRowHeight: CGFloat = 59
        static let secondRowTopOffset: CGFloat = 225
        static let secondRowHeight: CGFloat = 103
        static let thirdRowTopOffset: CGFloat = 341
        static let thirdRowHeight: CGFloat = 59
        static let fourthRowTopOffset: CGFloat = 413
        static let fourthRowHeight: CGFloat = 66
        static let buttonHeight: CGFloat = 52
        static let buttonCornerRadius: CGFloat = 12
        static let actionSpacing: CGFloat = 8
        static let balanceHeight: CGFloat = 18
        static let balanceBottomInset: CGFloat = 4
    }
}

final class StartStakingInfoSubtensorRowView: UIView {
    private let paragraphStyle = MultiColorTextStyle(
        textColor: R.color.colorTextPrimary()!,
        accentTextColor: R.color.colorButtonTextAccent()!,
        font: .regularBody
    )

    private let imageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    private let detailsLabel: UILabel = .create { label in
        label.numberOfLines = 0
    }

    init(iconTopOffset: CGFloat, showsDivider: Bool) {
        super.init(frame: .zero)

        addSubview(imageView)
        addSubview(detailsLabel)

        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(iconTopOffset)
            make.leading.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        detailsLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(Constants.textLeadingOffset)
            make.trailing.equalToSuperview()
        }

        if showsDivider {
            let divider = UIView()
            divider.backgroundColor = R.color.colorDivider()
            addSubview(divider)
            divider.snp.makeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                make.height.equalTo(Constants.dividerHeight)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ParagraphView.Model) {
        imageView.image = viewModel.image
        detailsLabel.bind(model: viewModel.text, with: paragraphStyle)
    }
}

private extension StartStakingInfoSubtensorRowView {
    enum Constants {
        static let iconSize: CGFloat = 40
        static let textLeadingOffset: CGFloat = 56
        static let dividerHeight: CGFloat = 0.5
    }
}
