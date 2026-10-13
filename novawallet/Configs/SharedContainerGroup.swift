import Foundation

enum SharedContainerGroup {
    static var name: String {
        #if F_RELEASE
            return "group.novafoundation.novawallet"
        #else
            return "group.novafoundation.novawallet.dev"
        #endif
    }
}
