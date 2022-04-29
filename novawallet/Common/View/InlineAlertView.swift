import UIKit
import SoraUI

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
        view.detailsLabel.textColor = R.color.colorWhite()
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
        view.backgroundView.fillColor = R.color.colorYellow12()!
        view.contentView.imageView.image = R.image.iconWarning()
        view.contentView.stackView.alignment = .top
        return view
    }

    static func error() -> InlineAlertView {
        let view = InlineAlertView()
        view.backgroundView.fillColor = R.color.colorRed12()!
        view.contentView.imageView.image = R.image.iconSlash()!
        view.contentView.stackView.alignment = .top
        return view
    }
}
