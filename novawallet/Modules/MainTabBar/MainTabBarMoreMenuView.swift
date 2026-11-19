import UIKit
import UIKit_iOS
import SnapKit

protocol MainTabBarMoreMenuViewDelegate: AnyObject {
    func moreMenuView(_ view: MainTabBarMoreMenuView, didSelect item: MainTabBarMoreItem)
    func moreMenuViewDidRequestDismiss(_ view: MainTabBarMoreMenuView)
}

final class MainTabBarMoreMenuView: UIView {
    weak var delegate: MainTabBarMoreMenuViewDelegate?

    let dimView: UIView = .create { view in
        view.backgroundColor = R.color.colorDimBackground()
        view.alpha = Constants.dimAlpha
    }

    let bubbleView: UIView = .create { view in
        view.clipsToBounds = true
        view.layer.cornerRadius = Constants.cornerRadius
        view.layer.borderWidth = Constants.borderWidth
        view.layer.borderColor = R.color.colorContainerBorder()!.cgColor
    }

    let bubbleBackgroundView: OverlayBlurBackgroundView = .create { view in
        view.sideLength = Constants.cornerRadius
        view.borderType = .none
        view.overlayView.fillColor = R.color.colorBlurNavigationBackground()!
    }

    let rowsStackView: UIStackView = .create { view in
        view.axis = .vertical
    }

    private var rows: [(item: MainTabBarMoreItem, row: MainTabBarMoreMenuRow)] = []
    private var modalCheckTimer: Timer?

    init(selectedItem: MainTabBarMoreItem?, locale: Locale) {
        super.init(frame: .zero)

        setupLayout()
        setupRows(selectedItem: selectedItem, locale: locale)
        setupHandlers()
    }

    deinit {
        modalCheckTimer?.invalidate()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        if newWindow == nil {
            stopModalCheck()
        }
    }

    func show(in containerView: UIView, above tabBar: UIView) {
        containerView.addSubview(self)

        snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(tabBar.snp.top)
        }

        alpha = 0

        UIView.animate(withDuration: Constants.animationDuration) {
            self.alpha = 1
        }
    }

    func requestDismissOnNewModal(_ modalsProvider: @escaping () -> [UIViewController]) {
        let initialModals = modalsProvider()

        modalCheckTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.modalCheckInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else {
                return
            }

            let hasNewModal = modalsProvider().contains { modal in
                !initialModals.contains { $0 === modal }
            }

            if hasNewModal {
                delegate?.moreMenuViewDidRequestDismiss(self)
            }
        }
    }

    func hide(animated: Bool) {
        stopModalCheck()

        isUserInteractionEnabled = false

        guard animated else {
            removeFromSuperview()
            return
        }

        UIView.animate(
            withDuration: Constants.animationDuration,
            animations: { self.alpha = 0 },
            completion: { _ in self.removeFromSuperview() }
        )
    }
}

// MARK: Private

private extension MainTabBarMoreMenuView {
    func setupLayout() {
        addSubview(dimView)
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(bubbleView)
        bubbleView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.bubbleTrailingInset)
            make.bottom.equalToSuperview().inset(Constants.bubbleBottomInset)
            make.width.equalTo(Constants.bubbleWidth)
        }

        bubbleView.addSubview(bubbleBackgroundView)
        bubbleBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bubbleView.addSubview(rowsStackView)
        rowsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupRows(selectedItem: MainTabBarMoreItem?, locale: Locale) {
        rows = MainTabBarMoreItem.allCases.map { item in
            let row = MainTabBarMoreMenuRow(frame: .zero)
            row.bind(
                title: item.title(for: locale),
                icon: item.icon,
                isSelected: item == selectedItem
            )

            return (item, row)
        }

        rows.enumerated().forEach { index, element in
            if index > 0 {
                rowsStackView.addArrangedSubview(createSeparator())
            }

            rowsStackView.addArrangedSubview(element.row)
        }
    }

    func setupHandlers() {
        rows.forEach { element in
            element.row.addTarget(self, action: #selector(actionRow(_:)), for: .touchUpInside)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionDismiss))
        dimView.addGestureRecognizer(tapGesture)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(actionDismiss),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    func stopModalCheck() {
        modalCheckTimer?.invalidate()
        modalCheckTimer = nil
    }

    func createSeparator() -> UIView {
        let view = UIView()
        view.backgroundColor = R.color.colorContainerBorder()

        view.snp.makeConstraints { make in
            make.height.equalTo(Constants.borderWidth)
        }

        return view
    }

    @objc func actionRow(_ sender: UIControl) {
        guard let item = rows.first(where: { $0.row === sender })?.item else {
            return
        }

        delegate?.moreMenuView(self, didSelect: item)
    }

    @objc func actionDismiss() {
        delegate?.moreMenuViewDidRequestDismiss(self)
    }
}

// MARK: Constants

private extension MainTabBarMoreMenuView {
    enum Constants {
        static let dimAlpha: CGFloat = 0.6
        static let cornerRadius: CGFloat = 18
        static let borderWidth: CGFloat = 1
        static let bubbleWidth: CGFloat = 238
        static let bubbleTrailingInset: CGFloat = 19
        static let bubbleBottomInset: CGFloat = 9
        static let animationDuration: TimeInterval = 0.2
        static let modalCheckInterval: TimeInterval = 0.2
    }
}

private extension MainTabBarMoreItem {
    var icon: UIImage? {
        switch self {
        case .governance:
            return R.image.iconMoreMenuGovernance()
        case .settings:
            return R.image.iconMoreMenuSettings()
        }
    }

    func title(for locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch self {
        case .governance:
            return strings.tabbarGovernanceTitle()
        case .settings:
            return strings.tabbarSettingsTitle()
        }
    }
}

final class MainTabBarMoreMenuRow: RowView<GenericTitleValueView<UILabel, UIImageView>> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        preferredHeight = Constants.height
        contentInsets = UIEdgeInsets(
            top: 0,
            left: Constants.horizontalInset,
            bottom: 0,
            right: Constants.horizontalInset
        )
        borderView.borderType = .none

        rowContentView.valueView.contentMode = .scaleAspectFit
        rowContentView.valueView.snp.makeConstraints { make in
            make.size.equalTo(Constants.iconSize)
        }
    }

    func bind(title: String, icon: UIImage?, isSelected: Bool) {
        rowContentView.titleView.apply(style: isSelected ? .regularBodyAccent : .regularBodyPrimary)
        rowContentView.titleView.text = title

        let iconColor = isSelected ? R.color.colorIconAccent()! : R.color.colorIconPrimary()!
        rowContentView.valueView.image = icon?.tinted(with: iconColor)
    }
}

private extension MainTabBarMoreMenuRow {
    enum Constants {
        static let height: CGFloat = 53
        static let horizontalInset: CGFloat = 17
        static let iconSize: CGFloat = 22
    }
}
