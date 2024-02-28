import UIKit

protocol DeviceOrientationManaging {
    var enabledOrientations: UIInterfaceOrientationMask { get }

    func enableLandscape()
    func disableLandscape()
}

final class DeviceOrientationManager {
    static let shared = DeviceOrientationManager(isLandscapeEnabled: false)

    private var isLandscapeEnabled: Bool

    init(isLandscapeEnabled: Bool) {
        self.isLandscapeEnabled = isLandscapeEnabled
    }
}

extension DeviceOrientationManager: DeviceOrientationManaging {
    var enabledOrientations: UIInterfaceOrientationMask {
        if isLandscapeEnabled {
            return [.portrait, .landscapeLeft, .landscapeRight]
        } else {
            return .portrait
        }
    }

    func enableLandscape() {
        isLandscapeEnabled = true
    }

    func disableLandscape() {
        isLandscapeEnabled = false
    }
}
