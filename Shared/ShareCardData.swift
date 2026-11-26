import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

struct ShareCardData {
    let items: [MenuCode.Item]
    let total: Int
    let usesSamples: Bool

    init(activities: [Activity]) {
        let shared = activities.filter { !$0.archived && $0.shareable }
        usesSamples = shared.isEmpty
        let source = shared.isEmpty ? Array(StarterIdeas.activities.prefix(3)) : shared
        total = source.count
        items = source.prefix(MenuCode.limit).map { .init(name: $0.name, minutes: $0.minutes) }
    }

    func imageCaption() throws -> String {
        let code = try MenuCode.encode(items)
        return L.t("share.caption") + "\n\n" + code
    }

    static func storeURL(_ id: String) -> URL? {
        guard !id.isEmpty, id.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)")
    }
}

enum DownloadQR {
    static func make(for url: URL) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let padded = output.composited(over: CIImage(color: .white))
            .cropped(to: output.extent.insetBy(dx: -4, dy: -4))
        let scaled = padded.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
