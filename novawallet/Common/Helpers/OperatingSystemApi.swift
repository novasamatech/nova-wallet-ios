import UIKit

protocol OperatingSystemMediating: AnyObject {
    func disableScreenSleep()
    func enableScreenSleep()
}

final class OperatingSystemMediator {
    let application: UIApplication

    init(application: UIApplication = .shared) {
        self.application = application
    }
}

extension OperatingSystemMediator: OperatingSystemMediating {
    func disableScreenSleep() {
        application.isIdleTimerDisabled = true
    }

    func enableScreenSleep() {
        application.isIdleTimerDisabled = false
    }
}
