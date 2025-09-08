import UIKit

protocol HiddableBarWhenPushed: AnyObject {}

protocol NavigationDependable: AnyObject {
    var navigationControlling: NavigationControlling? { get set }
}

protocol NavigationControlling: AnyObject {
    var isNavigationBarHidden: Bool { get }

    func setNavigationBarHidden(_ hidden: Bool, animated: Bool)
}

class NovaNavigationController: UINavigationController, UINavigationControllerDelegate {
    public var barSettings: NavigationBarSettings = .defaultSettings {
        didSet {
            applyBarStyle()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    override var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)

        definesPresentationContext = false
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        definesPresentationContext = false
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        definesPresentationContext = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        delegate = self

        view.backgroundColor = R.color.colorSecondaryScreenBackground()

        applyBarStyle()
    }

    func applyBarStyle() {
        let appearance = UINavigationBarAppearance()

        navigationBar.tintColor = barSettings.style.tintColor

        appearance.backgroundImage = barSettings.style.background

        appearance.shadowImage = barSettings.style.shadow

        appearance.shadowColor = barSettings.style.shadowColor

        let back = barSettings.style.backImage
        appearance.setBackIndicatorImage(back, transitionMaskImage: back)

        if let titleAttributes = barSettings.style.titleAttributes {
            appearance.titleTextAttributes = titleAttributes
        }

        appearance.backgroundEffect = barSettings.style.backgroundEffect

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        insertCloseButtonToRootIfNeeded()
    }

    // MARK: UINavigationControllerDelegate

    func navigationController(
        _: UINavigationController,
        willShow viewController: UIViewController,
        animated _: Bool
    ) {
        updateNavigationBarState(in: viewController)
        setupBackButtonItem(for: viewController)
    }

    // MARK: Private

    private func updateNavigationBarState(in viewController: UIViewController) {
        let isHidden = viewController is HiddableBarWhenPushed
        setNavigationBarHidden(isHidden, animated: true)

        if let navigationDependable = viewController as? NavigationDependable {
            navigationDependable.navigationControlling = self
        }
    }

    private func setupBackButtonItem(for viewController: UIViewController) {
        let backButtonItem = viewController.navigationItem.backBarButtonItem ?? UIBarButtonItem()
        backButtonItem.title = ""

        viewController.navigationItem.backBarButtonItem = backButtonItem
    }

    private func insertCloseButtonToRootIfNeeded() {
        if
            barSettings.shouldSetCloseButton,
            presentingViewController != nil,
            let rootViewController = viewControllers.first,
            rootViewController.navigationItem.leftBarButtonItem == nil {
            let closeItem = UIBarButtonItem(
                image: R.image.iconClose(),
                style: .plain,
                target: self,
                action: #selector(actionClose)
            )
            rootViewController.navigationItem.leftBarButtonItem = closeItem
        }
    }

    @objc private func actionClose() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension NovaNavigationController: NavigationControlling {}
