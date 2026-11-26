import SwiftUI
import UIKit

private enum CardLayout: String, CaseIterable, Identifiable {
    case standard, compact
    var id: String { rawValue }
}

@MainActor
struct ShareScreen: View {
    private struct RenderedCard {
        let layout: CardLayout
        let image: UIImage
        let hasQR: Bool
    }

    let activities: [Activity]
    let milestone: Bool
    let hasPro: Bool
    let back: () -> Void

    @State private var layout = CardLayout.standard
    @State private var renderedCard: RenderedCard?
    @State private var sharePayload: SharePayload?
    @State private var status: String?
    @State private var testCaption: String?
    @State private var busy = false

    private var card: ShareCardData { ShareCardData(activities: activities) }
    private var effectiveLayout: CardLayout { hasPro ? layout : .standard }
    private var hashtags: String { L.t(milestone ? "milestone.tags" : "share.tags") }
    private var currentCard: RenderedCard? { renderedCard?.layout == effectiveLayout ? renderedCard : nil }

    var body: some View {
        PageLayout {
            PaperButton(key: "common.back", id: "share.back", action: back)
        } content: {
            Paper.heading(L.t(milestone ? "milestone.open" : "share.menu"))
            if !milestone && card.usesSamples {
                Text(L.t("share.samples")).foregroundStyle(Paper.secondary).font(.footnote)
            }
            if !milestone && card.total > card.items.count {
                Text(L.f("share.limit", card.items.count, card.total)).foregroundStyle(Paper.secondary).font(.footnote)
            }
            if let currentCard {
                Image(uiImage: currentCard.image).resizable().scaledToFit()
                    .frame(maxWidth: 285).frame(maxWidth: .infinity)
                    .shadow(color: Paper.ink.opacity(0.07), radius: 12, y: 4)
                    .accessibilityLabel(previewLabel(hasQR: currentCard.hasQR))
                    .accessibilityValue(L.t("share.layout.\(currentCard.layout.rawValue)"))
                    .accessibilityIdentifier("share.preview")
            } else {
                ProgressView(L.t("common.loading")).frame(maxWidth: .infinity)
            }
        } footer: {
            if !milestone {
                HStack {
                    PaperButton(key: "share.copy", id: "share.copy", style: .outline, symbol: "doc.on.doc") {
                        do {
                            let code = try MenuCode.encode(card.items)
                            UIPasteboard.general.string = code
                            status = "share.copied"
                        } catch { status = "share.error" }
                    }
                    PaperButton(key: "share.file", id: "share.file", style: .outline, symbol: "doc") {
                        do {
                            let code = try MenuCode.encode(card.items)
                            Task { await share(bytes: Data(code.utf8), fileExtension: "txt", caption: nil) }
                        } catch { status = "share.error" }
                    }
                    .disabled(busy)
                }
            }
            if let status {
                Text(L.t(status)).font(.footnote)
                    .accessibilityValue(testCaption ?? "")
                    .accessibilityIdentifier(status == "share.requested" ? "share.requested" :
                                                status == "share.copied" ? "share.copied" : "share.error")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActions {
                if hasPro {
                    HStack(spacing: 4) {
                        ForEach(CardLayout.allCases) { option in
                            let selected = option == effectiveLayout
                            Button {
                                guard layout != option else { return }
                                renderedCard = nil
                                layout = option
                            } label: {
                                Text(L.t("share.layout.\(option.rawValue)"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selected ? Paper.emphasis : Paper.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44)
                                    .background(selected ? Paper.tint : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PaperPressStyle())
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("share.layout.\(option.rawValue)")
                            .disabled(busy)
                        }
                    }
                    .padding(4)
                    .background(Paper.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Paper.line) }
                }
                PaperButton(key: "share.image", id: "share.image", style: .primary,
                            symbol: "square.and.arrow.up", action: shareImage)
                    .disabled(busy || currentCard == nil)
            }
        }
        .task(id: effectiveLayout) { await render() }
        .sheet(item: $sharePayload) { payload in
            ActivitySheet(payload: payload)
        }
    }

    private func previewLabel(hasQR: Bool) -> String {
        let names = milestone ? [] : card.items.map { L.f("share.previewRow", $0.name, $0.minutes) }
        let download = L.t(hasQR ? "share.scan" : "share.placeholder")
        return ([L.t(milestone ? "milestone.title" : "share.cardTitle")] + names + [hashtags, download])
            .joined(separator: "\n")
    }

    private func render() async {
        let requestedLayout = effectiveLayout
        let id = Launch.testValue("DM_QR_STORE_ID")
            ?? (Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String ?? "")
        let qr = await Task.detached(priority: .userInitiated) {
            ShareCardData.storeURL(id).flatMap { DownloadQR.make(for: $0) }
        }.value
        guard !Task.isCancelled, requestedLayout == effectiveLayout else { return }
        let renderer = ImageRenderer(content: SharePoster(items: milestone ? [] : card.items,
                                                          milestone: milestone, layout: requestedLayout,
                                                          hashtags: hashtags, qr: qr))
        renderer.scale = 3
        renderer.isOpaque = true
        if let image = renderer.uiImage {
            renderedCard = RenderedCard(layout: requestedLayout, image: image, hasQR: qr != nil)
        } else {
            status = "share.error"
        }
    }

    private func shareImage() {
        guard let bytes = currentCard?.image.pngData() else {
            status = "share.error"
            return
        }
        do {
            let caption = try (milestone ? L.t("milestone.caption") : card.imageCaption())
            Task { await share(bytes: bytes, fileExtension: "png", caption: caption) }
        } catch {
            status = "share.error"
        }
    }

    private func share(bytes: Data, fileExtension: String, caption: String?) async {
        guard !busy else { return }
        status = nil
        busy = true
        defer { busy = false }
        if Launch.uiTesting {
            testCaption = caption
            status = "share.requested"
            return
        }

        let name = L.t("share.filename")
        let url = await Task.detached(priority: .userInitiated) { () -> URL? in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent(name).appendingPathExtension(fileExtension)
                try bytes.write(to: destination, options: .atomic)
                return destination
            } catch {
                try? FileManager.default.removeItem(at: folder)
                return nil
            }
        }.value
        if let url {
            sharePayload = SharePayload(url: url, caption: caption)
        } else {
            status = "share.error"
        }
    }
}

private struct SharePoster: View {
    let items: [MenuCode.Item]
    let milestone: Bool
    let layout: CardLayout
    let hashtags: String
    let qr: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t("app.name")).font(.system(size: 12, weight: .bold)).foregroundStyle(Paper.emphasis)
                    Text(L.t(milestone ? "milestone.title" : "share.cardTitle"))
                        .font(.system(size: 23, weight: .bold))
                        .lineLimit(2).minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                EmptyIllustration(symbol: milestone ? "checkmark.seal" : "cup.and.saucer.fill")
            }
            .padding(.horizontal, 10)
            .frame(height: 78)
            .background(Paper.heroGradient, in: RoundedRectangle(cornerRadius: 16))
            if milestone {
                Spacer(minLength: 0)
                Text(7, format: .number)
                    .font(.system(size: 130, weight: .bold, design: .rounded))
                    .foregroundStyle(Paper.emphasis)
                    .frame(maxWidth: .infinity)
                    .background(Paper.yellow.opacity(0.42), in: RoundedRectangle(cornerRadius: 18))
            } else {
                Text(L.t("share.estimated")).font(.system(size: 10)).foregroundStyle(Paper.secondary)
                VStack(spacing: 1) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        let appearance = ActivityAppearance.forName(item.name)
                        HStack(spacing: 7) {
                            SymbolBadge(symbol: appearance.symbol, color: appearance.color, size: 15)
                            Text(item.name).lineLimit(2).minimumScaleFactor(0.55)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(L.f("unit.minutes", item.minutes)).fontWeight(.semibold)
                                .monospacedDigit()
                                .padding(.horizontal, 5)
                                .background(appearance.color.opacity(0.36), in: Capsule())
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .frame(height: layout == .compact ? 17 : 18)
                        .background(layout == .compact ? Paper.tint : Paper.surface,
                                    in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            if milestone { Spacer(minLength: 0) }
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hashtags).font(.system(size: 11, weight: .semibold)).foregroundStyle(Paper.emphasis)
                    Text(L.t(qr == nil ? "share.placeholder" : "share.scan")).font(.system(size: 10))
                }.frame(maxWidth: .infinity, alignment: .leading)
                if let qr {
                    Image(decorative: qr, scale: 1).resizable().interpolation(.none)
                        .frame(width: 66, height: 66)
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 26)).foregroundStyle(Paper.emphasis)
                        .frame(width: 59, height: 59)
                        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.line, style: StrokeStyle(dash: [4, 3])) }
                }
            }
            .padding(.top, milestone ? 0 : 6)
        }
        .padding(19)
        .frame(width: 360, height: milestone ? 450 : nil)
        .foregroundStyle(Paper.ink)
        .background {
            let edge = RoundedRectangle(cornerRadius: 19)
            edge.fill(layout == .compact ? Paper.background : Paper.surface)
                .overlay {
                    edge.strokeBorder(LinearGradient(colors: [Paper.accent, Paper.tint, Paper.accent.opacity(0.65)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                                      lineWidth: 4)
                }
        }
        .background(Paper.background)
    }
}

private struct SharePayload: Identifiable {
    let url: URL
    let caption: String?
    var id: URL { url }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let payload: SharePayload

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [payload.url]
        if let caption = payload.caption { items.append(caption) }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let directory = payload.url.deletingLastPathComponent()
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task.detached(priority: .utility) { try? FileManager.default.removeItem(at: directory) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
