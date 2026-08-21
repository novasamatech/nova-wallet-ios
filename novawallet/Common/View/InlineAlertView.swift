import UIKit
import UIKit_iOS

final class InlineAlertView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.cornerRadius = 10.0
        return view
    }()

    let contentView: IconDetailsView = {
        let view = IconDetailsView()
        view.mode = .iconDetails
        view.detailsLabel.numberOfLines = 0
        view.iconWidth = Constants.iconWidth
        view.detailsLabel.textColor = R.color.colorTextPrimary()
        view.detailsLabel.font = .caption1
        view.spacing = Constants.iconTextSpacing
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Constants.verticalContentInset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalContentInset)
        }
    }
}

extension InlineAlertView {
    func apply(style: Style) {
        switch style {
        case .error:
            backgroundView.fillColor = R.color.colorErrorBlockBackground()!
            contentView.imageView.image = R.image.iconSlash()
        case .warning:
            backgroundView.fillColor = R.color.colorWarningBlockBackground()!
            contentView.imageView.image = R.image.iconWarning()
        case .info:
            backgroundView.fillColor = R.color.colorIndividualChipBackground()!
            contentView.imageView.image = R.image.iconInfoAccent()
        }

        contentView.stackView.alignment = .top
    }

    static func warning() -> InlineAlertView {
        let view = InlineAlertView()
        view.apply(style: .warning)
        return view
    }

    static func error() -> InlineAlertView {
        let view = InlineAlertView()
        view.apply(style: .error)
        return view
    }

    static func info() -> InlineAlertView {
        let view = InlineAlertView()
        view.apply(style: .info)
        return view
    }

    static func inline(for style: InlineAlertView.Style) -> InlineAlertView {
        switch style {
        case .error:
            return InlineAlertView.error()
        case .warning:
            return InlineAlertView.warning()
        case .info:
            return InlineAlertView.info()
        }
    }
}

extension InlineAlertView {
    enum Style {
        case error
        case warning
        case info
    }
}

extension InlineAlertView {
    enum Constants {
        static let horizontalContentInset: CGFloat = 16
        static let verticalContentInset: CGFloat = 10
        static let iconWidth: CGFloat = 16
        static let iconTextSpacing: CGFloat = 12
    }

    static func estimatedHeight(for message: String, width: CGFloat) -> CGFloat {
        let minHeight = Constants.iconWidth + 2 * Constants.verticalContentInset

        let textWidth = width - 2 * Constants.horizontalContentInset
            - Constants.iconWidth - Constants.iconTextSpacing

        guard textWidth > 0 else {
            return minHeight
        }

        let textHeight = message.estimateHeight(for: .caption1, width: textWidth)

        return max(ceil(textHeight) + 2 * Constants.verticalContentInset, minHeight)
    }
}
