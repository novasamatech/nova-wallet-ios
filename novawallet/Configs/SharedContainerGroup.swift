import Foundation

enum SharedContainerGroup {
    static var name: String {
        #if F_RELEASE
            return "group.novasamatech.novawallet"
        #else
            return "group.novasamatech.novawallet.dev"
        #endif
    }
}
