import Foundation
import Kingfisher

extension ImageDownloader {
    /// The downloader has a session of its own, which `URLProtocol.registerClass` doesn't reach
    func addProtocolClass(_ protocolClass: AnyClass) {
        // the downloader recreates its session when the configuration is assigned
        let configuration = sessionConfiguration
        configuration.protocolClasses = [protocolClass] + (configuration.protocolClasses ?? [])
        sessionConfiguration = configuration
    }
}
