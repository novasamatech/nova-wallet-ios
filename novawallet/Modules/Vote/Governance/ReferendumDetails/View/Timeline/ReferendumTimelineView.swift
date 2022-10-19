import UIKit
import SoraUI

final class ReferendumTimelineView: UIView {
    let dotsView = DotsView()
    let statusesContentView: UIStackView = .create {
        $0.axis = .vertical
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(dotsView)
        addSubview(statusesContentView)

        dotsView.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
            $0.width.equalTo(12)
        }

        statusesContentView.spacing = 12
        statusesContentView.snp.makeConstraints {
            $0.top.bottom.trailing.equalToSuperview()
            $0.leading.equalTo(dotsView.snp.trailing).inset(16)
        }
    }

    private func updateStatuses(model: Model) {
        let statusViews = statusViews(from: model)
        statusesContentView.arrangedSubviews.forEach {
            statusesContentView.removeArrangedSubview($0)
        }
        statusViews.forEach {
            statusesContentView.addArrangedSubview($0.view)
        }
        dotsView.points = statusViews.map {
            DotsView.Model(view: $0.view, isFinite: $0.status.isLast)
        }
    }

    private func statusViews(from model: Model) -> [(view: BaselinedView, status: Model.Status)] {
        model.statuses.map { status in
            switch status.subtitle {
            case let .date(date):
                let view = MultiValueView()
                view.valueTop.text = status.title
                view.valueTop.textAlignment = .left
                view.valueBottom.textAlignment = .left
                view.valueBottom.text = date
                return (view: view, status: status)
            case let .interval(model):
                let view = GenericMultiValueView<IconDetailsView>()
                view.valueTop.text = status.title
                view.valueTop.textAlignment = .left
                view.valueBottom.bind(viewModel: model)
                return (view: view, status: status)
            case .none:
                let label = UILabel()
                label.text = status.title
                return (view: label, status: status)
            }
        }
    }
}

extension ReferendumTimelineView: BindableView {
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
        dotsView.setNeedsDisplay()
        dotsView.setNeedsLayout()
    }
}
