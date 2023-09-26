import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import ZNSTextAttachment

public class NovaImageTextAttachment: NSTextAttachment {
    public let imageURL: URL

    private let origin: CGPoint?
    private let imageWidth: CGFloat?
    private let imageHeight: CGFloat?
    private let defaultImageExtension: String

    private var isLoading: Bool = false
    private var urlSessionDataTask: URLSessionDataTask?
    private var sources: [WeakWrapper] = []

    public init(
        imageURL: URL,
        imageWidth: CGFloat? = nil,
        imageHeight: CGFloat? = nil,
        placeholderImage: UIImage? = nil,
        placeholderImageOrigin: CGPoint? = nil,
        defaultImageExtension: String = "png"
    ) {
        self.imageURL = imageURL
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.defaultImageExtension = defaultImageExtension
        origin = placeholderImageOrigin

        if let placeholderImageData = placeholderImage?.pngData() {
            super.init(data: placeholderImageData, ofType: "public.png")
        } else {
            super.init(data: nil, ofType: nil)
        }

        image = placeholderImage
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func register(_ source: NovaTextAttachmentable) {
        sources.append(WeakWrapper(target: source))
    }

    public func startDownlaod() {
        guard !isLoading else { return }
        isLoading = true

        let urlSessionDataTask = URLSession.shared.dataTask(with: imageURL) { data, _, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription as Any)
                return
            }

            self.dataDownloaded(data)
            self.isLoading = false
            self.urlSessionDataTask = nil
        }
        self.urlSessionDataTask = urlSessionDataTask
        urlSessionDataTask.resume()
    }

    override public func attachmentBounds(
        for _: NSTextContainer?,
        proposedLineFragment _: CGRect,
        glyphPosition _: CGPoint,
        characterIndex _: Int
    ) -> CGRect {
        if let image = self.image {
            return CGRect(origin: origin ?? .zero, size: image.size)
        }

        return .zero
    }

    func dataDownloaded(_ data: Data) {
        let pathExtension = imageURL.pathExtension.isEmpty ? defaultImageExtension : imageURL.pathExtension
        let fileType = getFileType(from: pathExtension)

        let image = UIImage(data: data)

        DispatchQueue.main.async {
            let loaded = ZResizableNSTextAttachment(
                imageSize: image?.size,
                fixedWidth: self.imageWidth,
                fixedHeight: self.imageHeight,
                data: data,
                type: fileType
            )
            self.sources.compactMap {
                $0.target as? NovaTextAttachmentable
            }.forEach {
                $0.replace(attachment: self, with: loaded)
            }
        }
    }

    private func getFileType(from pathExtension: String) -> String {
        if #available(iOS 14.0, *) {
            if let utType = UTType(filenameExtension: pathExtension) {
                return utType.identifier
            } else {
                return pathExtension
            }
        } else {
            if let utType = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension,
                pathExtension as CFString,
                nil
            ) {
                return utType.takeRetainedValue() as String
            } else {
                return pathExtension
            }
        }
    }
}

public extension NovaImageTextAttachment {
    override func image(forBounds _: CGRect, textContainer: NSTextContainer?, characterIndex _: Int) -> UIImage? {
        if let textStorage = textContainer?.layoutManager?.textStorage {
            register(textStorage)
        }

        startDownlaod()

        if let image = self.image {
            return image
        }

        return nil
    }
}
