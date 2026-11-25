import Foundation

protocol ConfigMirrorURLResolverProtocol {
    /// Returns where the mirror serves the file or `nil` when the mirror doesn't have it.
    func mirrorURL(for url: URL) -> URL?
}

struct ConfigMirrorURLResolver {
    static let shared = ConfigMirrorURLResolver(applicationConfig: ApplicationConfig.shared)

    let mirrorBaseURL: URL
    let sources: [String]

    init(mirrorBaseURL: URL, sources: [String]) {
        self.mirrorBaseURL = mirrorBaseURL
        self.sources = sources
    }

    init(applicationConfig: ApplicationConfigProtocol) {
        mirrorBaseURL = applicationConfig.configMirrorBaseURL
        sources = applicationConfig.configMirrorSources
    }
}

extension ConfigMirrorURLResolver: ConfigMirrorURLResolverProtocol {
    func mirrorURL(for url: URL) -> URL? {
        let original = url.absoluteString

        guard original.hasPrefix(Constants.scheme) else {
            return nil
        }

        // Some urls are assembled with NSString path helpers that collapse "https://" into "https:/",
        // URLSession still loads them, so the number of slashes can't be relied on.
        let schemeless = original.dropFirst(Constants.scheme.count)
        let location = schemeless.drop { $0 == Constants.pathSeparator }

        guard
            location.count < schemeless.count,
            let source = sources.first(where: { location.hasPrefix($0) }) else {
            return nil
        }

        // The file path is taken as is to keep its percent encoding
        let filePath = location.dropFirst(source.count)

        guard !filePath.isEmpty, !hasParentReference(in: filePath) else {
            return nil
        }

        return URL(string: mirrorBaseURL.absoluteString + filePath)
    }
}

private extension ConfigMirrorURLResolver {
    enum Constants {
        static let scheme = "https:"
        static let pathSeparator: Character = "/"
        static let parentReference = ".."
        static let pathTerminators: Set<Character> = ["?", "#"]
    }

    // A path that climbs up could leave the mirror's config directory, whoever normalizes it on the way
    func hasParentReference(in filePath: Substring) -> Bool {
        let path = filePath.prefix { !Constants.pathTerminators.contains($0) }

        return path
            .split(separator: Constants.pathSeparator, omittingEmptySubsequences: false)
            .contains { ($0.removingPercentEncoding ?? String($0)) == Constants.parentReference }
    }
}
