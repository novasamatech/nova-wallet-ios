import Cuckoo
import Foundation_iOS
@testable import novawallet
import UIKit
import XCTest

final class SubtensorModalStackTests: XCTestCase {
    private struct World {
        let container: UIViewController
        let tabBarController: UITabBarController
        let hostNavigation: UINavigationController
        let hostRoot: UIViewController
    }

    func testDismissingAboveTheTabBarClosesTheResultAndTheFlowCardUnderIt() {
        let world = makeWorld()
        let flowNavigation = presentFlowCard(from: world.hostRoot)
        let result = presentResult(from: flowNavigation)

        XCTAssertTrue(result.presentingViewController === world.container)
        XCTAssertTrue(flowNavigation.presentingViewController === world.tabBarController)

        dismissStack(above: world.tabBarController)

        XCTAssertNil(world.container.presentedViewController)
        XCTAssertNil(world.tabBarController.presentedViewController)
    }

    func testDismissingAboveTheTabBarKeepsTheAppLockPinOverTheFlowCard() {
        let world = makeWorld()
        let flowNavigation = presentFlowCard(from: world.hostRoot)
        let pin = presentAppLockPin(in: world)

        dismissStack(above: world.tabBarController)

        XCTAssertTrue(world.container.presentedViewController === pin)
        XCTAssertNil(flowNavigation.presentingViewController)
    }

    func testDismissingAboveTheTabBarKeepsTheResultTheAppLockPinCovers() {
        let world = makeWorld()
        let flowNavigation = presentFlowCard(from: world.hostRoot)
        let result = presentResult(from: flowNavigation)
        let pin = presentAppLockPin(in: world)

        dismissStack(above: world.tabBarController)

        XCTAssertTrue(world.container.presentedViewController === result)
        XCTAssertTrue(result.presentedViewController === pin)
        XCTAssertNil(flowNavigation.presentingViewController)
    }

    func testClosingYourBittensorDismissesTheFlowWithItsResultAndPopsTheHostTab() {
        let world = makeWorld()
        let portfolio = UIViewController()
        world.hostNavigation.pushViewController(portfolio, animated: false)

        _ = presentResult(from: presentFlowCard(from: portfolio))

        let view = MockSubtensorPortfolioViewProtocol()

        stub(view) { stub in
            when(stub.controller.get).thenReturn(portfolio)
        }

        SubtensorPortfolioWireframe(state: MockSubtensorStakingSharedStateProtocol()).close(from: view)

        spinMainRunLoop { world.hostNavigation.viewControllers == [world.hostRoot] }

        XCTAssertEqual(world.hostNavigation.viewControllers, [world.hostRoot])
        XCTAssertNil(world.container.presentedViewController)
        XCTAssertNil(world.tabBarController.presentedViewController)
    }

    private func makeWorld() -> World {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let container = UIViewController()
        let tabBarController = UITabBarController()
        let hostRoot = UIViewController()
        let hostNavigation = NovaNavigationController(rootViewController: hostRoot)

        tabBarController.viewControllers = [hostNavigation]
        tabBarController.definesPresentationContext = true
        container.addChild(tabBarController)
        container.view.addSubview(tabBarController.view)
        tabBarController.didMove(toParent: container)
        window.rootViewController = container
        window.makeKeyAndVisible()

        addTeardownBlock {
            window.isHidden = true
        }

        return World(
            container: container,
            tabBarController: tabBarController,
            hostNavigation: hostNavigation,
            hostRoot: hostRoot
        )
    }

    private func presentFlowCard(from host: UIViewController) -> UINavigationController {
        let flowNavigation = ImportantFlowViewFactory.createNavigation(from: UIViewController())
        let cardShown = expectation(description: "Flow card shown")

        host.presentWithCardLayout(flowNavigation, animated: false) {
            cardShown.fulfill()
        }

        wait(for: [cardShown], timeout: 10)

        return flowNavigation
    }

    private func presentResult(from flowNavigation: UINavigationController) -> UIViewController {
        let presenter = MockSubtensorResultPresenterProtocol()

        stub(presenter) { stub in
            when(stub.setup()).thenDoNothing()
        }

        let confirm = UIViewController()
        let result = SubtensorOperationResultViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        result.modalPresentationStyle = .fullScreen
        flowNavigation.pushViewController(confirm, animated: false)

        let resultShown = expectation(description: "Result shown over the flow card")

        confirm.present(result, animated: false) {
            resultShown.fulfill()
        }

        wait(for: [resultShown], timeout: 10)

        return result
    }

    private func presentAppLockPin(in world: World) -> UIViewController {
        let presenter = MockPinSetupPresenterProtocol()

        stub(presenter) { stub in
            when(stub.start()).thenDoNothing()
        }

        let pin = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pin.presenter = presenter
        pin.modalTransitionStyle = .crossDissolve
        pin.modalPresentationStyle = .overFullScreen

        let pinShown = expectation(description: "App lock PIN shown")

        world.container.topModalViewController.present(pin, animated: false) {
            pinShown.fulfill()
        }

        wait(for: [pinShown], timeout: 10)

        return pin
    }

    private func dismissStack(above tabBarController: UITabBarController) {
        let stackDismissed = expectation(description: "Modal stack dismissed")

        SubtensorModalStack.dismiss(above: tabBarController, animated: false) {
            stackDismissed.fulfill()
        }

        wait(for: [stackDismissed], timeout: 10)
    }

    private func spinMainRunLoop(until condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: 10)

        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
    }
}
