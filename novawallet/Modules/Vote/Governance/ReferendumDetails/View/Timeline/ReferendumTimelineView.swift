import UIKit
import UIKit_iOS

final class ReferendumTimelineView: UIView {
    private enum Constants {
        static let horizontalSpacing: CGFloat = 15
        static let verticalSpacing: CGFloat = 48
        static let alignmentOffset: CGFloat = -1
        static let titleSubtitleSpacing: CGFloat = 2
    }

    let dotsView = DotsView()
    private var statusViews: [UIView] = []

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

        dotsView.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
        }
    }

    private func updateStatuses(model: [Model]) {
        let statusViews = statusViews(from: model)

        self.statusViews.forEach {
            $0.removeFromSuperview()
        }

        self.statusViews = statusViews

        statusViews.enumerated().forEach { index, view in
            addSubview(view)

            let topInset = CGFloat(index) * Constants.verticalSpacing + Constants.alignmentOffset

            view.snp.makeConstraints { make in
                make.leading.equalTo(dotsView.snp.trailing).offset(Constants.horizontalSpacing)
                make.top.equalToSuperview().inset(topInset)
            }
        }

        dotsView.points = model.map {
            DotsView.Model(isFinite: $0.isLast)
        }
    }

    private func statusViews(from model: [Model]) -> [UIView] {
        model.map { status in
            switch status.subtitle {
            case let .date(date):
                let view = MultiValueView()
                view.spacing = Constants.titleSubtitleSpacing
                view.valueTop.text = status.title
                view.valueTop.textAlignment = .left
                view.valueTop.apply(style: .timelineTitle)
                view.valueBottom.apply(style: .timelineNeutralSubtitle)
                view.valueBottom.textAlignment = .left
                view.valueBottom.text = date
                return view
            case let .interval(model):
                let view = GenericMultiValueView<IconDetailsView>()
                view.spacing = Constants.titleSubtitleSpacing
                view.valueTop.text = status.title
                view.valueTop.textAlignment = .left
                view.valueTop.apply(style: .timelineTitle)
                view.valueBottom.detailsLabel.numberOfLines = 1

                if model.isUrgent {
                    view.valueBottom.detailsLabel.apply(style: .timelineUrgentSubtitle)
                } else {
                    view.valueBottom.detailsLabel.apply(style: .timelineNeutralSubtitle)
                }

                view.valueBottom.spacing = 5
                view.valueBottom.iconWidth = 14
                view.valueBottom.bind(viewModel: model.titleIcon)
                return view
            case .none:
                let label = UILabel()
                label.text = status.title
                label.apply(style: UILabel.Style.rowTitle)
                return label
            }
        }
    }
}

extension ReferendumTimelineView: BindableView {
    struct Model {
        let title: String
        let subtitle: StatusSubtitle?
        let isLast: Bool
    }

    enum StatusSubtitle {
        case date(String)
        case interval(ReferendumInfoView.Time)
    }

    func bind(viewModel: [Model]) {
        updateStatuses(model: viewModel)
        setNeedsLayout()
    }

    func bind(activeTimeViewModel: ReferendumInfoView.Time?) {
        guard let activeView = statusViews.last as? GenericMultiValueView<IconDetailsView> else {
            return
        }

        if let activeTimeViewModel = activeTimeViewModel {
            if activeTimeViewModel.isUrgent {
                activeView.valueBottom.detailsLabel.apply(style: UILabel.Style.timelineUrgentSubtitle)
            } else {
                activeView.valueBottom.detailsLabel.apply(style: UILabel.Style.timelineNeutralSubtitle)
            }

            activeView.valueBottom.bind(viewModel: activeTimeViewModel.titleIcon)
        } else {
            activeView.valueBottom.bind(viewModel: nil)
        }

        setNeedsLayout()
    }
}

private extension UILabel.Style {
    static var timelineTitle: UILabel.Style {
        .init(textColor: R.color.colorTextPrimary()!, font: .regularFootnote)
    }

    static var timelineNeutralSubtitle: UILabel.Style {
        .init(textColor: R.color.colorTextSecondary()!, font: .caption1)
    }

    static var timelineUrgentSubtitle: UILabel.Style {
        .init(textColor: R.color.colorTextWarning()!, font: .caption1)
    }
}
