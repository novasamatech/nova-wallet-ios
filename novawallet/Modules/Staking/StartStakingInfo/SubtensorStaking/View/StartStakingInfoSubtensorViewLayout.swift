import UIKit
import UIKit_iOS

final class StartStakingInfoSubtensorViewLayout: UIView {
    private let titleStyle = MultiColorTextStyle(
        textColor: R.color.colorTextPrimary()!,
        accentTextColor: R.color.colorButtonTextAccent()!,
        font: .boldTitle1
    )

    let containerView: ScrollableContainerView = .create { view in
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = Constants.contentInsets
        view.stackView.alignment = .fill
    }

    let titleLabel: UILabel = .create { label in
        label.textAlignment = .center
        label.numberOfLines = 0
    }

    let earningRows = [
        StartStakingInfoSubtensorRowView(showsDivider: true),
        StartStakingInfoSubtensorRowView(showsDivider: true),
        StartStakingInfoSubtensorRowView(showsDivider: true),
        StartStakingInfoSubtensorRowView(showsDivider: false)
    ]

    let actionButton: RoundedButton = .create { button in
        button.applySecondaryStyle()
        button.roundedBackgroundView?.cornerRadius = Constants.buttonCornerRadius
        button.imageWithTitleView?.titleFont = .semiBoldSubheadline
        button.imageWithTitleView?.titleColor = R.color.colorButtonText()
    }

    let balanceLabel = UILabel(style: .caption1Secondary, textAlignment: .center, numberOfLines: 1)

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

        actionButton.imageWithTitleView?.title = viewModel.actionTitle
        actionButton.invalidateLayout()
    }
}

private extension StartStakingInfoSubtensorViewLayout {
    func setupLayout() {
        addSubview(balanceLabel)
        balanceLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.balanceHeight)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(Constants.balanceBottomInset)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(Constants.buttonHeight)
            make.bottom.equalTo(balanceLabel.snp.top).offset(-Constants.actionSpacing)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-Constants.contentBottomSpacing)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(Constants.titleSpacing, after: titleLabel)

        for row in earningRows {
            containerView.stackView.addArrangedSubview(row)
            containerView.stackView.setCustomSpacing(Constants.rowSpacing, after: row)
        }
    }
}

extension StartStakingInfoSubtensorViewLayout {
    enum Constants {
        static let horizontalInset: CGFloat = 16
        static let contentInsets = UIEdgeInsets(top: 24, left: 16, bottom: 16, right: 16)
        static let titleSpacing: CGFloat = 32
        static let rowSpacing: CGFloat = 14
        static let contentBottomSpacing: CGFloat = 16
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

    init(showsDivider: Bool) {
        super.init(frame: .zero)

        let contentView = UIView.hStack(
            alignment: .center,
            spacing: Constants.textSpacing,
            [imageView, detailsLabel]
        )

        addSubview(contentView)

        imageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }

        guard showsDivider else {
            contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            return
        }

        let divider = UIView()
        divider.backgroundColor = R.color.colorDivider()
        addSubview(divider)

        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        divider.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.bottom).offset(Constants.dividerSpacing)
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(Constants.dividerHeight)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ParagraphView.Model) {
        imageView.image = viewModel.image

        let text = NSAttributedString(
            string: viewModel.text.text,
            attributes: [
                .foregroundColor: paragraphStyle.textColor,
                .font: paragraphStyle.font
            ]
        )

        let decorators = viewModel.text.accents.map { accent in
            HighlightingAttributedStringDecorator(
                pattern: accent,
                attributes: [.foregroundColor: paragraphStyle.accentTextColor]
            )
        }

        detailsLabel.attributedText = CompoundAttributedStringDecorator(decorators: decorators)
            .decorate(attributedString: text)
    }
}

private extension StartStakingInfoSubtensorRowView {
    enum Constants {
        static let iconSize: CGFloat = 40
        static let textSpacing: CGFloat = 16
        static let dividerSpacing: CGFloat = 16
        static let dividerHeight: CGFloat = 0.5
    }
}
