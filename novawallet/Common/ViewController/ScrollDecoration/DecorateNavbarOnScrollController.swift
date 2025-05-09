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

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDecorationView()
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
    func setupDecorationView() {
        view.addSubview(decorationView)

        decorationView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
    }
}
