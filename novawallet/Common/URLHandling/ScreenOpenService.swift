import Foundation
import SubstrateSdk

protocol ScreenOpenDelegate: AnyObject {
    func didAskScreenOpen(_ screen: UrlHandlingScreen)
}

enum UrlHandlingScreen: String {
    case staking
}

protocol ScreenOpenServiceProtocol: URLHandlingServiceProtocol {
    var delegate: ScreenOpenDelegate? { get set }

    func consumePendingScreenOpen() -> UrlHandlingScreen?
}

final class ScreenOpenService {
    weak var delegate: ScreenOpenDelegate?

    private var pendingScreen: UrlHandlingScreen?

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

extension ScreenOpenService: ScreenOpenServiceProtocol {
    func handle(url: URL) -> Bool {
        // we are expecting nova/open/{screen}
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3 else {
            return false
        }

        guard UrlHandlingAction(rawValue: pathComponents[1]) == .open else {
            return false
        }

        guard let screen = UrlHandlingScreen(rawValue: pathComponents[2]) else {
            logger.warning("unsupported screen: \(pathComponents[2])")
            return false
        }

        DispatchQueue.main.async { [weak self] in
            if let delegate = self?.delegate {
                self?.pendingScreen = nil
                delegate.didAskScreenOpen(screen)
            } else {
                self?.pendingScreen = screen
            }
        }

        return true
    }

    func consumePendingScreenOpen() -> UrlHandlingScreen? {
        let screen = pendingScreen

        pendingScreen = nil

        return screen
    }
}
