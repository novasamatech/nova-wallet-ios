import Foundation

protocol InAppUpdatesUrlProviderProtocol {
    var releaseURL: URL { get }
    func versionURL(_ version: ReleaseVersion) -> URL
}

final class InAppUpdatesUrlProvider: InAppUpdatesUrlProviderProtocol {
    let applicationConfig: ApplicationConfigProtocol

    init(applicationConfig: ApplicationConfigProtocol) {
        self.applicationConfig = applicationConfig
    }

    var releaseURL: URL {
        applicationConfig.inAppUpdatesEntrypointURL
    }

    func versionURL(_ version: ReleaseVersion) -> URL {
        let changelogURL = applicationConfig.inAppUpdatesChangelogsURL
        let fileName = [
            version.major,
            version.minor,
            version.patch
        ]
        .map { String($0) }
        .joined(separator: "_")
        .appending(".md")

        return changelogURL.appendingPathComponent(fileName)
    }
}
