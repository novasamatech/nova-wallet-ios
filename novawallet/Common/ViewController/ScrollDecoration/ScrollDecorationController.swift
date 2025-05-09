import UIKit

class ScrollDecorationController: UIViewController {
    let scrollHost: ScrollViewHostControlling

    init(scrollHost: ScrollViewHostControlling) {
        self.scrollHost = scrollHost

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScrollHost()
    }

    func handleContentOffsetChange(_: CGPoint) {
        fatalError("Subsclass must implement the method")
    }
}

private extension ScrollDecorationController {
    func setupScrollHost() {
        addChild(scrollHost.controller)
        view.addSubview(scrollHost.controller.view)
        scrollHost.controller.didMove(toParent: self)

        scrollHost.controller.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollHost.scrollViewTracker = self
    }
}

extension ScrollDecorationController: ScrollViewTrackingProtocol {
    func trackScrollViewDidChangeOffset(_ newOffset: CGPoint) {
        handleContentOffsetChange(newOffset)
    }
}
