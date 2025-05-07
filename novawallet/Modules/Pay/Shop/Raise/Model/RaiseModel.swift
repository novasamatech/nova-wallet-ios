import Foundation

enum RaiseModel {
    // TODO: Decide about list of countries
    static var allowedCountries: Set<String>? {
        #if F_RELEASE
            ["us"]
        #else
            nil
        #endif
    }
}
