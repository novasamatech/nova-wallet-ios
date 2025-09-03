import Foundation

struct GlobalConfig: Decodable {
    let multiStakingApiUrl: URL
    let multisigsApiUrl: URL
    let proxyApiUrl: URL
}
