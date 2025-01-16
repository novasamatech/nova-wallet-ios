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
        view.iconWidth = 16.0
        view.detailsLabel.textColor = R.color.colorTextPrimary()
        view.detailsLabel.font = .caption1
        view.spacing = 12.0
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
            make.top.bottom.equalToSuperview().inset(10.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }
    }
}

extension InlineAlertView {
    static func warning() -> InlineAlertView {
        let view = InlineAlertView()
        view.backgroundView.fillColor = R.color.colorWarningBlockBackground()!
        view.contentView.imageView.image = R.image.iconWarning()
        view.contentView.stackView.alignment = .top
        return view
    }

    static func error() -> InlineAlertView {
        let view = InlineAlertView()
        view.backgroundView.fillColor = R.color.colorErrorBlockBackground()!
        view.contentView.imageView.image = R.image.iconSlash()!
        view.contentView.stackView.alignment = .top
        return view
    }

    static func info() -> InlineAlertView {
        let view = InlineAlertView()
        view.backgroundView.fillColor = R.color.colorIndividualChipBackground()!
        view.contentView.imageView.image = R.image.iconInfoAccent()!
        view.contentView.stackView.alignment = .top
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
