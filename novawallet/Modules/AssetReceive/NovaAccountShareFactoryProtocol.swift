import UIKit

public protocol NovaAccountShareFactoryProtocol {
    func createSources(for receiveInfo: AssetReceiveInfo, qrImage: UIImage) -> [Any]
}
