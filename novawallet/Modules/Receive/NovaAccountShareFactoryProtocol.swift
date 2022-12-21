import UIKit

public protocol NovaAccountShareFactoryProtocol {
    func createSources(for receiveInfo: NovaReceiveInfo, qrImage: UIImage) -> [Any]
}
