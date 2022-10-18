import UIKit
import SoraUI

final class ReferendumTimelineView: UIView {
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
        content = UIView.vStack(statusesView)
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 44, bottom: 0, right: 0))
        }
    }

    private func updateStatuses(model: Model) {
        layoutIfNeeded()
        statusesView = createStatusesView(from: model)
        content.arrangedSubviews.forEach {
            content.removeArrangedSubview($0)
        }
        content.addArrangedSubview(UIView.vStack(statusesView))
        statusesView.forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(44)
            }
        }
    }

    private func createStatusesView(from model: Model) -> [BaselinedView] {
        model.statuses.map { status -> BaselinedView in
            switch status.subtitle {
            case let .date(date):
                let view = MultiValueView()
                view.valueTop.text = status.title
                view.valueTop.textAlignment = .left
                view.valueBottom.textAlignment = .left
                view.valueBottom.text = date
                return view
            case let .interval(model):
                let view = GenericMultiValueView<IconDetailsView>()
                view.valueTop.text = status.title
                view.valueTop.textAlignment = .left
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
