import UIKit

final class DotsOverlayView: UIView {
    var configuration: Configuration = .default {
        didSet {
            setNeedsDisplay()
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        let width = CGFloat(configuration.numberOfDots)
            * configuration.dotSize
            + CGFloat(configuration.numberOfDots - 1)
            * configuration.spacing
        let height = configuration.dotSize

        return CGSize(width: width, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setFillColor(configuration.dotColor.cgColor)

        let totalWidth = intrinsicContentSize.width
        let startX: CGFloat

        switch configuration.alignment {
        case .left:
            startX = 0
        case .center:
            startX = (rect.width - totalWidth) / 2
        case .right:
            startX = rect.width - totalWidth
        }

        let centerY = rect.height / 2

        for index in 0 ..< configuration.numberOfDots {
            let dotCenterX = startX
                + configuration.dotSize / 2
                + CGFloat(index)
                * (configuration.dotSize + configuration.spacing)

            let dotRect = CGRect(
                x: dotCenterX - configuration.dotSize / 2,
                y: centerY - configuration.dotSize / 2,
                width: configuration.dotSize,
                height: configuration.dotSize
            )

            context.fillEllipse(in: dotRect)
        }
    }
}

// MARK: - Private

private extension DotsOverlayView {
    func setup() {
        backgroundColor = .clear
        isOpaque = false
    }
}

// MARK: - Configuration

extension DotsOverlayView {
    struct Configuration {
        let dotSize: CGFloat
        let spacing: CGFloat
        let numberOfDots: Int
        let dotColor: UIColor
        let alignment: Alignment

        enum Alignment {
            case left
            case center
            case right
        }

        static let `default` = smallBalance

        static let smallBalance = Configuration(
            dotSize: 4,
            spacing: 4,
            numberOfDots: 4,
            dotColor: R.color.colorTextSecondary()!,
            alignment: .left
        )

        static let largeBalance = Configuration(
            dotSize: 10,
            spacing: 6,
            numberOfDots: 4,
            dotColor: R.color.colorTextPrimary()!,
            alignment: .left
        )
    }
}
