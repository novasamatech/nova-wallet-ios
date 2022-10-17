import UIKit
import SoraUI

final class DotsView: UIView {
    var statusesView: [BaselinedView] = []

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        print("createDots")
        createDots()
    }

    private func createDots() {
        let dotX = frame.midX

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.setStrokeColor(R.color.colorNovaBlue()!.cgColor)
        context.setFillColor(R.color.colorNovaBlue()!.cgColor)
        context.setLineWidth(1)
        for index in 0 ..< statusesView.count {
            let dotY = statusesView[index].firstBaseline.center.y
            let firstDot = UIBezierPath(
                arcCenter: .init(x: dotX, y: dotY),
                radius: 6,
                startAngle: 0,
                endAngle: 2 * .pi,
                clockwise: true
            )

            firstDot.move(to: .init(x: dotX, y: dotY + 6))
            print("x1: \(dotX), y1: \(dotY + 6)")
            if index + 1 >= statusesView.count {
                return
            }
            statusesView[index].firstBaseline.layoutIfNeeded()
            statusesView[index + 1].firstBaseline.layoutIfNeeded()

            print("1: \(statusesView[index].firstBaseline.frame)")
            print("2: \(statusesView[index + 1].firstBaseline.frame)")

            let nextDotY = statusesView[index + 1].firstBaseline.center.y
            firstDot.addLine(to: .init(x: dotX, y: nextDotY))
            firstDot.stroke()
            firstDot.fill()

            let secondDot = UIBezierPath(
                arcCenter: .init(x: dotX, y: nextDotY),
                radius: 6,
                startAngle: 0,
                endAngle: 2 * .pi,
                clockwise: true
            )
            secondDot.stroke()
            secondDot.fill()
            print("x2: \(dotX), y2: \(nextDotY)")
        }
    }

    override var intrinsicContentSize: CGSize {
        .init(width: 12, height: UIView.noIntrinsicMetric)
    }
}

final class ReferendumTimelineView: UIView {
    var dotsView = DotsView()
    private(set) var statusesView: [BaselinedView] = []
    var content = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        content = UIView.hStack(
            [
                dotsView,
                UIView.vStack(statusesView)
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    private func updateStatuses(model: Model) {
        layoutIfNeeded()
        statusesView = createStatusesView(from: model)
        content.arrangedSubviews.forEach {
            content.removeArrangedSubview($0)
        }
        content.addArrangedSubview(dotsView)
        content.addArrangedSubview(UIView.vStack(statusesView))
        statusesView.forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(44)
            }
        }
        content.setNeedsLayout()
        content.layoutIfNeeded()
        dotsView.statusesView = statusesView
        dotsView.setNeedsDisplay()
    }

    private func createStatusesView(from model: Model) -> [BaselinedView] {
        model.statuses.map { status -> BaselinedView in
            switch status.subtitle {
            case let .date(date):
                let view = MultiValueView()
                view.valueTop.text = status.title
                view.valueBottom.text = date
                return view
            case let .interval(model):
                let view = GenericMultiValueView<IconDetailsView>()
                view.valueTop.text = status.title
                view.valueBottom.bind(viewModel: model)
                return view
            case .none:
                let label = UILabel()
                label.text = status.title
                return label
            }
        }
    }
}

extension ReferendumTimelineView {
    struct Model {
        let title: String
        let statuses: [Status]

        struct Status {
            let title: String
            let subtitle: StatusSubtitle?
            let isLast: Bool
        }

        enum StatusSubtitle {
            case date(String)
            case interval(TitleIconViewModel)
        }
    }

    func bind(viewModel: Model) {
        updateStatuses(model: viewModel)
    }
}

protocol BaselinedView: UIView {
    var firstBaseline: UIView { get }
}

extension GenericMultiValueView: BaselinedView {
    var firstBaseline: UIView {
        valueTop
    }
}

extension UILabel: BaselinedView {
    var firstBaseline: UIView {
        self
    }
}
