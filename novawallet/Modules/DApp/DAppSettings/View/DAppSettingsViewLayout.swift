import UIKit
import SnapKit

final class DAppSettingsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleRow = StackTableHeaderCell()
    let favoriteRow = DAppFavoriteSettingsView(frame: .zero)
    let desktopModeRow = DAppDesktopModeSettingsView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)

        containerView.stackView.addArrangedSubview(titleRow)
        containerView.stackView.addArrangedSubview(favoriteRow)
        containerView.stackView.addArrangedSubview(desktopModeRow)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var preferredHeight: CGFloat {
        [titleRow.preferredHeight,
         favoriteRow.preferredHeight,
         desktopModeRow.preferredHeight].compactMap { $0 }.reduce(0, +)
    }
}
