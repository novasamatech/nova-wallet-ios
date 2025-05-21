import UIKit
import Foundation_iOS

final class PayRootViewController: UIViewController, ViewHolder {
    typealias RootViewType = PayRootViewLayout

    let presenter: PayRootPresenterProtocol
    private var pageProvider: PageViewProviding?
    private var currentPageView: ControllerBackedProtocol?

    weak var scrollViewTracker: ScrollViewTrackingProtocol? {
        didSet {
            updateInnerScrollHostTracker()
        }
    }

    init(presenter: PayRootPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

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

        presenter.setup()
    }
}

private extension PayRootViewController {
    func setupLocalization() {
        applySegmentedControlItems()
    }

    func applySegmentedControlItems() {
        guard let pageProvider else { return }

        let pageCount = pageProvider.numberOfPages()

        let segmentTitles = (0 ..< pageCount).map { index in
            pageProvider.getPageTitle(at: index, locale: selectedLocale)
        }

        rootView.segmentedControl.titles = segmentTitles
    }

    func configureSegmentedControl() {
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

        guard let pageView = pageProvider?.getPageView(at: index) else {
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
        guard let pageProvider else {
            return
        }

        let numberOfPages = pageProvider.numberOfPages()

        let nextIndex = (rootView.segmentedControl.selectedSegmentIndex + 1) % numberOfPages

        rootView.segmentedControl.selectedSegmentIndex = nextIndex

        applyPage(index: nextIndex)
    }
}

extension PayRootViewController: PayRootViewProtocol {
    func didReceive(pageProvider: PageViewProviding) {
        let hadProvider = self.pageProvider != nil

        self.pageProvider = pageProvider

        applySegmentedControlItems()

        let selectedIndex = hadProvider ?
            min(rootView.segmentedControl.selectedSegmentIndex, pageProvider.numberOfPages() - 1) :
            pageProvider.initialPageIndex()

        rootView.segmentedControl.selectedSegmentIndex = selectedIndex

        applyPage(index: selectedIndex)
    }
}

extension PayRootViewController: ScrollViewHostControlling {
    var initialTrackingInsets: UIEdgeInsets {
        guard let scrollViewHost = currentPageView as? ScrollViewHostControlling else {
            return .zero
        }

        return scrollViewHost.initialTrackingInsets
    }
}

extension PayRootViewController: ScrollDecorationProviding {
    func provideTopBarExtensionDecoration() -> UIView {
        rootView.provideTopBarExtensionDecoration()
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
