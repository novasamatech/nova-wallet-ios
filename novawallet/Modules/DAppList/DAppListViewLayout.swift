import UIKit

final class DAppListViewLayout: UIView {
    let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

    let headerView = DAppListHeaderView()

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .fill
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
        return view
    }()

    let listHeaderTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h3Title
        return label
    }()

    let subIdControlView: ControlView<TriangularedBlurView, DAppContentView> = {
        let backgroundView = TriangularedBlurView()
        let contentView = DAppContentView()

        let view = ControlView(backgroundView: backgroundView, contentView: contentView)
        view.changesContentOpacityWhenHighlighted = true
        view.contentInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }

        containerView.stackView.addArrangedSubview(headerView)

        containerView.stackView.setCustomSpacing(24.0, after: headerView)

        containerView.stackView.addArrangedSubview(listHeaderTitleLabel)
        containerView.stackView.setCustomSpacing(16.0, after: listHeaderTitleLabel)

        containerView.stackView.addArrangedSubview(subIdControlView)
    }
}
