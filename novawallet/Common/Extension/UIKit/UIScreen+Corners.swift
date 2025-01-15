import UIKit

extension UIScreen {
    var cornerRadius: CGFloat {
        let identifier = deviceModelIdentifier()

        switch identifier {
        case "iPhone10,3", "iPhone10,6",
             "iPhone11,2",
             "iPhone11,4", "iPhone11,6",
             "iPhone12,3",
             "iPhone12,5":
            return 39.0

        case "iPhone11,8",
             "iPhone12,1":
            return 41.5

        case "iPhone13,1",
             "iPhone14,4":
            return 44.0

        case "iPhone13,2",
             "iPhone13,3",
             "iPhone14,2",
             "iPhone14,7":
            return 47.33

        case "iPhone13,4",
             "iPhone14,3",
             "iPhone14,8":
            return 53.33

        case "iPhone15,2",
             "iPhone15,3",
             "iPhone15,4",
             "iPhone15,5",
             "iPhone16,1",
             "iPhone16,2",
             "iPhone17,3",
             "iPhone17,4":
            return 55.0

        case "iPhone17,1",
             "iPhone17,2":
            return 62.0
        default:
            return 0
        }
    }

    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
