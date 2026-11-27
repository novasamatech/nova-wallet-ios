import Foundation

protocol ConfigMirrorURLResolverProtocol {
    /// Returns where the mirror serves the file or `nil` when the mirror doesn't have it.
    func mirrorURL(for url: URL) -> URL?
}

/// Maps a url under one of the source directories to the same file path under the mirror directory.
/// A url is mapped only when its scheme and host are exactly the source's ones and it carries no port
/// or credentials. Anything else is not the mirror's business and is left where it is.
struct ConfigMirrorURLResolver {
    private let mirrorBaseURL: URL
    private let sources: [Source]

    /// Both the mirror and the sources are directories, so their paths are expected to end with a slash
    init(mirrorBaseURL: URL, sources: [URL]) {
        self.mirrorBaseURL = mirrorBaseURL
        self.sources = sources.compactMap { Source(url: $0) }
    }

    init(applicationConfig: ApplicationConfigProtocol) {
        self.init(
            mirrorBaseURL: applicationConfig.configMirrorBaseURL,
            sources: applicationConfig.configMirrorSources
        )
    }
}

extension ConfigMirrorURLResolver: ConfigMirrorURLResolverProtocol {
    func mirrorURL(for url: URL) -> URL? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            components.user == nil,
            components.password == nil,
            components.port == nil,
            let source = sources.first(where: { $0.contains(components) }) else {
            return nil
        }

        // The file path is taken as is to keep its percent encoding
        let filePath = components.percentEncodedPath.dropFirst(source.directoryPath.count)

        guard
            !filePath.isEmpty,
            !hasDotSegment(in: filePath),
            var mirrorComponents = URLComponents(url: mirrorBaseURL, resolvingAgainstBaseURL: true) else {
            return nil
        }

        // the query and the fragment stay behind: the mirror ignores them and a file has neither
        mirrorComponents.percentEncodedPath += filePath

        return mirrorComponents.url
    }
}

// MARK: Private

private extension ConfigMirrorURLResolver {
    struct Source {
        let scheme: String
        let host: String
        let directoryPath: String

        init?(url: URL) {
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                let scheme = components.scheme,
                let host = components.host,
                components.percentEncodedPath.hasSuffix(String(Constants.pathSeparator)) else {
                return nil
            }

            self.scheme = scheme
            self.host = host
            directoryPath = components.percentEncodedPath
        }

        func contains(_ components: URLComponents) -> Bool {
            components.scheme == scheme &&
                components.host == host &&
                components.percentEncodedPath.hasPrefix(directoryPath)
        }
    }

    enum Constants {
        static let pathSeparator: Character = "/"
        static let dotSegments: Set<Substring> = [".", ".."]
    }

    // A path that climbs up could leave the mirror's directory, whoever normalizes it on the way.
    // The path is decoded before it is split for an encoded dot or slash not to hide a segment.
    func hasDotSegment(in filePath: Substring) -> Bool {
        guard let decodedPath = filePath.removingPercentEncoding else {
            // what can't be decoded can't be checked
            return true
        }

        return decodedPath
            .split(separator: Constants.pathSeparator, omittingEmptySubsequences: false)
            .contains { Constants.dotSegments.contains($0) }
    }
}
