import UIKit
import UIKit_iOS

class DecorateNavbarOnScrollController: ScrollDecorationController {
    private let decorationView: BlurBackgroundView = .create { view in
        view.cornerCut = []
        view.alpha = 0.0
    }

    private let animator = BlockViewAnimator()
    private let threshold: CGFloat = 0.0
    private var isDecorationActive = false
    private let decorationProvider: ScrollDecorationProviding?

    init(scrollHost: ScrollViewHostControlling, decorationProvider: ScrollDecorationProviding? = nil) {
        self.decorationProvider = decorationProvider

        super.init(scrollHost: scrollHost)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let barExtendingView = decorationProvider?.provideTopBarExtensionDecoration()

        setupDecorationView(with: barExtendingView)
    }

    override func handleContentOffsetChange(_ newOffset: CGPoint) {
        let willBeActive = predictDecorationActive(for: newOffset)

        if willBeActive != isDecorationActive {
            isDecorationActive = willBeActive

            animator.animate(
                block: { [weak self] in
                    self?.decorationView.alpha = willBeActive ? 1.0 : 0.0
                },
                completionBlock: nil
            )
        }
    }
}

private extension DecorateNavbarOnScrollController {
    func predictDecorationActive(for newOffset: CGPoint) -> Bool {
        let initialInsets = scrollHost.initialTrackingInsets

        return initialInsets.top + newOffset.y > threshold
    }
}

private extension DecorateNavbarOnScrollController {
    func setupDecorationView(with barExtendingView: UIView?) {
        view.addSubview(decorationView)

        if let barExtendingView {
            view.addSubview(barExtendingView)
        }

        barExtendingView?.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }

        decorationView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()

            if let barExtendingView {
                make.bottom.equalTo(barExtendingView.snp.bottom)
            } else {
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top)
            }
        }
    }
}
