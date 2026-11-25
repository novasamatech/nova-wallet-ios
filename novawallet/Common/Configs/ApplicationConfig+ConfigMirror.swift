import Foundation

extension ApplicationConfig {
    // A compile-time constant on purpose: the global config that carries `infraUrl` is itself fetched
    // through the mirror. The host must match `infraUrl` in nova-utils `global/config*.json`.
    var configMirrorBaseURL: URL {
        #if F_RELEASE
            URL(string: "https://nova-infra.novasama-tech.org/v1/config/")!
        #else
            URL(string: "https://nova-infra-dev.novasama-tech.org/v1/config/")!
        #endif
    }

    // Only the master branch of nova-utils is mirrored; GitHub serves it under both forms.
    var configMirrorSources: [String] {
        [
            "raw.githubusercontent.com/novasamatech/nova-utils/master/",
            "raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/"
        ]
    }
}
