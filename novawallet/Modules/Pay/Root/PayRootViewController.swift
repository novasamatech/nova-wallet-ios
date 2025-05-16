import UIKit
import Foundation_iOS

final class PayRootViewController: UIViewController, ViewHolder {
    typealias RootViewType = PayRootViewLayout

    let pageProvider: PageViewProviding

    private var currentPageView: ControllerBackedProtocol?

    weak var scrollViewTracker: ScrollViewTrackingProtocol? {
        didSet {
            updateInnerScrollHostTracker()
        }
    }

    init(
        pageProvider: PageViewProviding,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.pageProvider = pageProvider

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PayRootViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        configureSegmentedControl()
        configureSwipeControl()

        applyPage(index: pageProvider.initialPageIndex())
    }
}

private extension PayRootViewController {
    func setupLocalization() {
        applySegmentedControlLocale()
    }

    func applySegmentedControlLocale() {
        let pageCount = pageProvider.numberOfPages()

        let segmentTitles = (0 ..< pageCount).map { index in
            pageProvider.getPageTitle(at: index, locale: selectedLocale)
        }

        rootView.segmentedControl.titles = segmentTitles
    }

    func configureSegmentedControl() {
        rootView.segmentedControl.selectedSegmentIndex = pageProvider.initialPageIndex()

        rootView.segmentedControl.addTarget(
            self,
            action: #selector(actionSegmentedControlValueChanged),
            for: .touchUpInside
        )
    }

    func configureSwipeControl() {
        let swipeRecognizer = UISwipeGestureRecognizer(
            target: self,
            action: #selector(actionSwipeToSwitch)
        )

        swipeRecognizer.direction = [.left, .right]

        rootView.addGestureRecognizer(swipeRecognizer)
    }

    func applyPage(index: Int) {
        clearCurrentPageView()

        guard let pageView = pageProvider.getPageView(at: index) else {
            return
        }

        addChild(pageView.controller)

        pageView.controller.additionalSafeAreaInsets = UIEdgeInsets(
            top: rootView.segmentedControlAreaHeight,
            left: 0,
            bottom: 0,
            right: 0
        )

        rootView.setupPage(view: pageView.controller.view)
        pageView.controller.didMove(toParent: self)

        currentPageView = pageView

        updateInnerScrollHostTracker()

        scrollViewTracker?.trackScrollViewDidChangeOffset(
            CGPoint(x: initialTrackingInsets.left, y: initialTrackingInsets.top)
        )
    }

    func clearCurrentPageView() {
        currentPageView?.controller.view.removeFromSuperview()
        currentPageView?.controller.removeFromParent()
        currentPageView?.controller.didMove(toParent: nil)
        currentPageView = nil
    }

    func updateInnerScrollHostTracker() {
        if let scrollHost = currentPageView as? ScrollViewHostProtocol {
            scrollHost.scrollViewTracker = scrollViewTracker
        }
    }

    @objc func actionSegmentedControlValueChanged() {
        let selectedIndex = rootView.segmentedControl.selectedSegmentIndex

        applyPage(index: selectedIndex)
    }

    @objc func actionSwipeToSwitch() {
        let numberOfPages = pageProvider.numberOfPages()

        let nextIndex = (rootView.segmentedControl.selectedSegmentIndex + 1) % numberOfPages

        rootView.segmentedControl.selectedSegmentIndex = nextIndex

        applyPage(index: nextIndex)
    }
}

extension PayRootViewController: PayRootViewProtocol {}

extension PayRootViewController: ScrollViewHostControlling {
    var initialTrackingInsets: UIEdgeInsets {
        guard let scrollViewHost = currentPageView as? ScrollViewHostControlling else {
            return .zero
        }

        return scrollViewHost.initialTrackingInsets
    }
}

extension PayRootViewController: ScrollsToTop {
    func scrollToTop() {
        guard let scrollViewHost = currentPageView as? ScrollsToTop else {
            return
        }

        scrollViewHost.scrollToTop()
    }
}

extension PayRootViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
