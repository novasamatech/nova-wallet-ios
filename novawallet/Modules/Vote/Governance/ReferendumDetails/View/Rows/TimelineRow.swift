import UIKit
import SoraUI

final class TimelineRow: RoundedView, BindableView {
    typealias TModel = [ReferendumTimelineView.Model]

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorTransparentText()
        $0.font = .regularFootnote
    }

    let contentView = ReferendumTimelineView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        applyCellBackgroundStyle()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: [ReferendumTimelineView.Model]) {
        contentView.bind(viewModel: viewModel)
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: 16,
            [
                titleLabel,
                contentView
            ]
        )

        addSubview(content)
        content.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }
    }
}
