import UIKit
import Foundation_iOS

final class StakingMainViewLayout: UIView {
    let backgroundView = MultigradientView.background

    let navBarBlurView: BlurBackgroundView = .create { view in
        view.cornerCut = []
    }

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        view.stackView.distribution = .fill
        view.stackView.spacing = 0.0
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
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        addSubview(navBarBlurView)
        navBarBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
        }
    }
}
