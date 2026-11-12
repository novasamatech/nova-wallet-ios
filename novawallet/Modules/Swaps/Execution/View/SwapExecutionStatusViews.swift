import UIKit
import UIKit_iOS

final class SwapExecutionStatusMarkView: UIView {
    let backgroundView: RoundedView = .create {
        $0.applyFilledBackgroundStyle()
    }

    let iconView: UIImageView = .create {
        $0.contentMode = .scaleAspectFit
    }

    private var iconSize: CGFloat

    init(size: CGFloat, iconSize: CGFloat) {
        self.iconSize = iconSize

        super.init(frame: .zero)

        backgroundView.cornerRadius = size / 2

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.size.equalTo(size)
        }

        addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(iconSize)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(isSuccess: Bool) {
        backgroundView.fillColor = isSuccess ? R.color.colorIconPositive()! : R.color.colorIconNegative()!
        backgroundView.highlightedFillColor = backgroundView.fillColor

        let icon = isSuccess ? R.image.iconCheckmark() : R.image.iconClose()
        iconView.image = icon?.tinted(with: R.color.colorIconPrimary()!)
    }
}

final class SwapExecutionResultTileView: UIView {
    let haloView: RoundedView = .create {
        $0.applyFilledBackgroundStyle()
        $0.cornerRadius = Constants.haloSize / 2
    }

    let markView = SwapExecutionStatusMarkView(size: Constants.markSize, iconSize: Constants.iconSize)

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(haloView)
        haloView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.size.equalTo(Constants.haloSize)
        }

        addSubview(markView)
        markView.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(isSuccess: Bool) {
        haloView.fillColor = isSuccess
            ? R.color.colorActiveStatusBackground()!
            : R.color.colorIconNegative()!.withAlphaComponent(Constants.failureHaloAlpha)
        haloView.highlightedFillColor = haloView.fillColor

        markView.bind(isSuccess: isSuccess)
    }
}

extension SwapExecutionResultTileView {
    enum Constants {
        static let haloSize: CGFloat = 72
        static let markSize: CGFloat = 52
        static let iconSize: CGFloat = 28
        static let failureHaloAlpha: CGFloat = 0.24
    }
}
