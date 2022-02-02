import UIKit

extension UIColor {
    public convenience init?(hex: String) {
        let red, green, blue: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    red = CGFloat((hexNumber & 0x00FF_0000) >> 16) / 255
                    green = CGFloat((hexNumber & 0x0000_FF00) >> 8) / 255
                    blue = CGFloat(hexNumber & 0x0000_00FF) / 255

                    self.init(red: red, green: green, blue: blue, alpha: 1.0)
                    return
                }
            }
        }

        return nil
    }

    // swiftlint:disable:next large_tuple
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var rComponent: CGFloat = 0
        var gComponent: CGFloat = 0
        var bComponent: CGFloat = 0
        var aComponent: CGFloat = 0

        if getRed(&rComponent, green: &gComponent, blue: &bComponent, alpha: &aComponent) {
            return (rComponent, gComponent, bComponent, aComponent)
        }

        return (0, 0, 0, 0)
    }

    var hexRGB: String {
        String(
            format: "#%02X%02X%02X",
            Int(rgbaComponents.red * 255),
            Int(rgbaComponents.green * 255),
            Int(rgbaComponents.blue * 255)
        )
    }

    var hexRGBA: String {
        String(
            format: "#%02X%02X%02X%02X",
            Int(rgbaComponents.red * 255),
            Int(rgbaComponents.green * 255),
            Int(rgbaComponents.blue * 255),
            Int(rgbaComponents.alpha * 255)
        )
    }
}
