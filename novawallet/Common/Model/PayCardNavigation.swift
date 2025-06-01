import Foundation

enum PayCardNavigation {
    case mercuryo
    case `default`

    init(providerString: String?) {
        switch providerString?.lowercased() {
        case "mercuryo":
            self = .mercuryo
        default:
            self = .default
        }
    }
}
