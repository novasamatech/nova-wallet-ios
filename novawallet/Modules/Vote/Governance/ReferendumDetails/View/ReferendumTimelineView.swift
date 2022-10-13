import UIKit
import SoraUI

final class ReferendumTimelineView: UIView {
    let dotsView = UIView()
    private(set) var statusesView: [BaselinedView] = []

    private func setupLayout() {
        let content = UIView.hStack(
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

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    private func updateStatuses(model: Model) {
        statusesView = createStatusesView(from: model)
        setNeedsLayout()
    }

    private func createDots() {
        let dotX = dotsView.center.x

        for statusView in statusesView {
            let dotY = statusView.firstBaseline.center.y
            let path = UIBezierPath(
                arcCenter: .init(x: dotX, y: dotY),
                radius: 6,
                startAngle: 0,
                endAngle: 2 * .pi,
                clockwise: true
            )
        }
    }

    private func createStatusesView(from model: Model) -> [BaselinedView] {
        model.statuses.map { status in
            switch status.subtitle {
            case let .date(date):
                let view = MultiValueView()
                view.valueTop.text = status.title
                view.valueBottom.text = date
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

    func bind(viewModel _: Model) {
        setupLayout(model: model)
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
