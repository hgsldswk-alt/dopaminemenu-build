import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor
struct PersonalMenu: View {
    @ObservedObject var model: AppModel
    let back: () -> Void
    let history: () -> Void
    let edit: (Activity?) -> Void
    let share: () -> Void

    private var active: [Activity] { model.data.activities.filter { !$0.archived } }
    private var archived: [Activity] { model.data.activities.filter(\.archived) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PaperButton(key: "common.menu", id: "menu.back", action: back)
                Spacer()
                PaperButton(key: "history.title", id: "menu.history", style: .outline,
                            symbol: "clock.arrow.circlepath", action: history)
            }
            .padding(.horizontal, 21)
            Paper.heading(L.t("menu.title"))
                .padding(.horizontal, 21)
            List {
                Section {
                    if active.isEmpty {
                        EmptyState(symbol: "list.bullet") {
                            Text(L.t("menu.empty"))
                            addButton
                        }
                        .listRowBackground(Paper.background)
                        .listRowSeparator(.hidden)
                    } else {
                        addButton
                            .listRowBackground(Paper.background)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(Array(active.enumerated()), id: \.element.id) { index, item in
                        ActivityCard(activity: item, id: "menu.activity.\(index)", start: false) { edit(item) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    model.setArchived(item.id, archived: true)
                                } label: {
                                    Label(L.t("editor.archive"), systemImage: "archivebox")
                                }
                                .tint(Paper.emphasis)
                                .accessibilityIdentifier("menu.archive.\(index)")
                            }
                            .listRowBackground(Paper.background)
                            .listRowSeparator(.hidden)
                    }
                    PaperButton(key: "share.menu", id: "menu.share", style: .outline,
                                symbol: "square.and.arrow.up", action: share)
                        .listRowBackground(Paper.background)
                        .listRowSeparator(.hidden)
                }
                Section {
                    VStack(spacing: 8) {
                        Toggle(L.t("menu.timer"), isOn: Binding(get: { model.data.showsTimer }, set: model.setTimerPreference))
                            .frame(minHeight: 44).accessibilityIdentifier("menu.timer")
                        Divider()
                        Toggle(L.t("menu.haptics"), isOn: Binding(get: { model.data.haptics }, set: model.setHaptics))
                            .frame(minHeight: 44).accessibilityIdentifier("menu.haptics")
                    }
                    .padding(12).paperCard()
                    .listRowBackground(Paper.background)
                    .listRowSeparator(.hidden)
                }
                if !archived.isEmpty {
                    Section {
                        ForEach(Array(archived.enumerated()), id: \.element.id) { index, item in
                            let appearance = ActivityAppearance.forName(item.name, group: item.group)
                            IconRow(symbol: appearance.symbol, color: appearance.color) {
                                Text(item.name)
                                    .accessibilityIdentifier("archive.activity.\(index)")
                            } detail: {
                                Text(item.group.isEmpty ? appearance.title : item.group)
                                StatusPill(text: L.f("unit.minutes", item.minutes),
                                           color: appearance.color.opacity(0.40))
                            } trailing: {
                                PaperButton(key: "archive.restore", id: "archive.restore.\(index)",
                                            symbol: "arrow.uturn.backward") {
                                    model.setArchived(item.id, archived: false)
                                }
                                .accessibilityLabel(L.f("archive.restoreActivity", item.name))
                            }
                            .listRowBackground(Paper.background)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text(L.t("menu.archive")).sectionHeading().accessibilityIdentifier("menu.archived")
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(22)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: 522)
        .frame(maxWidth: .infinity)
        .foregroundStyle(Paper.ink)
        .background(Paper.background.ignoresSafeArea())
    }

    private var addButton: some View {
        PaperButton(key: "editor.add", id: "menu.add", style: .primary, symbol: "plus") { edit(nil) }
    }
}

struct ActivityEditor: View {
    @Binding var activity: Activity
    let hasPro: Bool
    let saved: Bool
    let cancel: () -> Void
    let save: () -> Void
    let archive: () -> Void
    @FocusState private var focused: Bool
    @State private var choseStarter = false

    private var name: String { activity.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        PageLayout {
            PaperButton(key: "common.cancel", id: "editor.cancel", action: cancel)
        } content: {
            Paper.heading(L.t(saved ? "editor.edit" : "editor.add"))
            TextField(L.t("editor.name"), text: $activity.name)
                .textFieldStyle(.plain).focused($focused)
                .paperField().accessibilityIdentifier("editor.name")
            if !name.isEmpty && !MenuCode.validName(name) {
                Text(L.t("editor.invalidName")).font(.footnote).foregroundStyle(Paper.emphasis)
            }
            if !saved && !choseStarter {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("home.starters")).sectionHeading()
                        .accessibilityIdentifier("editor.starters")
                    ForEach(Array(StarterIdeas.activities.enumerated()), id: \.element.id) { index, idea in
                        ActivityCard(activity: idea, id: "starters.activity.\(index)", start: false) {
                            activity.name = idea.name
                            activity.minutes = idea.minutes
                            activity.lowEnergy = idea.lowEnergy
                            choseStarter = true
                            focused = true
                        }
                    }
                }
            }
            Text(L.f("editor.duration", activity.minutes)).sectionHeading()
                .accessibilityIdentifier("editor.duration")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                ForEach(1...30, id: \.self) { minutes in
                    let selected = activity.minutes == minutes
                    Button {
                        activity.minutes = minutes
                        focused = false
                    } label: {
                        Text(minutes, format: .number)
                            .font(.system(.body, design: .rounded, weight: .semibold)).monospacedDigit()
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? Paper.yellow : Paper.surface, in: RoundedRectangle(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Paper.ink : Paper.line)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PaperPressStyle())
                    .accessibilityLabel(L.f("unit.minutes", minutes))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("editor.minutes.\(minutes)")
                }
            }
            VStack(spacing: 8) {
                Toggle(L.t("editor.low"), isOn: $activity.lowEnergy)
                    .frame(minHeight: 44).accessibilityIdentifier("editor.low")
                Divider()
                Toggle(L.t("editor.share"), isOn: $activity.shareable)
                    .frame(minHeight: 44).accessibilityIdentifier("editor.share")
            }
            .padding(12).paperCard()
            TextField(L.t("editor.hint"), text: $activity.hint, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(2...4)
                .paperField().accessibilityIdentifier("editor.hint")
            if hasPro || !activity.group.isEmpty {
                TextField(L.t("editor.group"), text: $activity.group)
                    .textFieldStyle(.plain).paperField()
                    .accessibilityIdentifier("editor.group")
                    .disabled(!hasPro)
            }
        } footer: {}
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActions {
                if saved {
                    PaperButton(key: activity.archived ? "editor.unarchive" : "editor.archive",
                                id: "editor.archive", style: .outline, symbol: "archivebox", action: archive)
                        .padding(.bottom, 4)
                }
                PaperButton(key: "common.save", id: "editor.save", style: .primary) {
                    focused = false
                    let trimmedName = name
                    let trimmedGroup = activity.group.trimmingCharacters(in: .whitespacesAndNewlines)
                    activity.name = trimmedName
                    activity.group = trimmedGroup
                    save()
                }
                .disabled(!MenuCode.validName(name))
            }
        }
        .task {
            if !saved { focused = true }
        }
    }
}

@MainActor
struct HistoryScreen: View {
    @ObservedObject var model: AppModel
    let back: () -> Void
    let share: () -> Void
    @State private var period: Calendar.Component?

    private var records: [Completion] {
        guard model.hasPro, let period,
              let interval = Calendar.current.dateInterval(of: period, for: .now) else { return model.data.history }
        return model.data.history.filter { interval.contains($0.date) }
    }

    var body: some View {
        PageLayout {
            PaperButton(key: "common.back", id: "history.back", action: back)
        } content: {
            Paper.heading(L.t("history.title")).accessibilityIdentifier("history.title")
            if model.data.reachedMilestone {
                PaperButton(key: "milestone.open", id: "history.milestone", style: .outline,
                            symbol: "sparkles", action: share)
            }
            if model.hasPro {
                HStack {
                    periodButton("history.all", id: "history.all", for: nil)
                    periodButton("history.week", id: "history.week", for: .weekOfYear)
                    periodButton("history.month", id: "history.month", for: .month)
                }
                if period != nil {
                    StatusPill(text: L.f("history.count", records.count), color: Paper.mint.opacity(0.40))
                }
            }
            if records.isEmpty {
                EmptyState(symbol: "clock.arrow.circlepath") {
                    Text(L.t("history.empty"))
                    if period != nil {
                        PrimaryButton(title: L.t("history.all"), symbol: "calendar") { period = nil }
                    } else {
                        PrimaryButton(title: L.t("done.back"), symbol: "list.bullet", action: back)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(records) { record in
                        let appearance = ActivityAppearance.forName(record.activity.name, group: record.activity.group)
                        IconRow(symbol: appearance.symbol, color: appearance.color) {
                            Text(record.activity.name)
                        } detail: {
                            Text(record.date, format: .dateTime.year().month().day())
                        } trailing: {
                            StatusPill(text: L.f("unit.minutes", record.activity.minutes), color: appearance.color.opacity(0.40))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("history.record.\(record.id.uuidString)")
                    }
                }
            }
        } footer: {}
    }

    private func periodButton(_ key: String, id: String, for value: Calendar.Component?) -> some View {
        PaperButton(key: key, id: id, style: value == period ? .outline : .text) { period = value }
            .accessibilityAddTraits(value == period ? .isSelected : [])
    }
}

@MainActor
struct ImportScreen: View {
    @ObservedObject var model: AppModel
    let back: () -> Void
    @State private var text = ""
    @State private var status: String?
    @State private var importingFile = false
    @State private var importedCount: Int?
    @FocusState private var focused: Bool

    private var decoded: [MenuCode.Item]? { try? MenuCode.decode(text) }
    private var preview: MenuCode.Merge? { decoded.map { MenuCode.merge($0, existing: model.data.activities) } }

    var body: some View {
        PageLayout {
            PaperButton(key: "common.menu", id: "import.back", action: back)
        } content: {
            Paper.heading(L.t("import.title"))
            Text(L.t("import.instructions")).foregroundStyle(Paper.secondary)
            HStack {
                PaperButton(key: "import.paste", id: "import.paste", style: .outline, symbol: "doc.on.clipboard") {
                    let pasted = Launch.testFlag("-paste-denied") ? nil
                        : Launch.testValue("DM_PASTE_CODE") ?? UIPasteboard.general.string
                    if let pasted, !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        focused = false
                        setCode(pasted)
                    } else {
                        status = "import.noPaste"
                        focused = true
                    }
                }
                PaperButton(key: "import.file", id: "import.file", style: .outline, symbol: "folder") { importingFile = true }
            }
            TextEditor(text: Binding(get: { text }, set: setCode))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 95)
                .paperField()
                .accessibilityLabel(L.t("import.field"))
                .accessibilityIdentifier("import.code")
                .focused($focused)
            if let importedCount {
                Text(L.f("import.added", importedCount)).accessibilityIdentifier("import.success")
            } else if let status {
                Text(L.t(status)).foregroundStyle(Paper.emphasis).accessibilityIdentifier("import.error")
            } else if let preview {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.f("import.new", preview.newItems.count)).sectionHeading().accessibilityIdentifier("import.preview")
                    if preview.duplicates > 0 {
                        Text(L.f("import.duplicates", preview.duplicates)).font(.footnote).foregroundStyle(Paper.secondary)
                    }
                    if preview.newItems.isEmpty {
                        EmptyState(symbol: "tray.and.arrow.down") {
                            Text(L.t("import.instructions"))
                            PrimaryButton(title: L.t("import.field"), symbol: "pencil") { focused = true }
                        }
                    }
                    ForEach(preview.newItems, id: \.self) { item in
                        let appearance = ActivityAppearance.forName(item.name)
                        IconRow(symbol: appearance.symbol, color: appearance.color) {
                            Text(item.name)
                        } detail: {
                            Text(appearance.title)
                        } trailing: {
                            StatusPill(text: L.f("unit.minutes", item.minutes), color: appearance.color.opacity(0.40))
                        }
                    }
                }
            } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(L.t(validationMessage)).foregroundStyle(Paper.emphasis).accessibilityIdentifier("import.error")
            }
        } footer: {}
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomActions {
                PaperButton(key: "import.add", id: "import.add", style: .primary, symbol: "square.and.arrow.down") {
                    guard let preview, !preview.newItems.isEmpty else { return }
                    focused = false
                    model.merge(preview.newItems)
                    importedCount = preview.newItems.count
                    status = nil
                }
                .disabled(preview?.newItems.isEmpty != false)
            }
        }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.plainText]) { result in
            switch result {
            case .success(let url):
                Task { await readFile(url) }
            case .failure:
                status = "import.fileError"
            }
        }
    }

    private var validationMessage: String {
        do { _ = try MenuCode.decode(text); return "import.invalid" }
        catch MenuCode.Invalid.length { return "import.tooLong" }
        catch MenuCode.Invalid.version { return "import.version" }
        catch { return "import.invalid" }
    }

    private func setCode(_ code: String) {
        text = code
        status = nil
        importedCount = nil
    }

    private func readFile(_ url: URL) async {
        let input = await Task.detached(priority: .userInitiated) { () -> String? in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            guard let bytes = try? handle.read(upToCount: MenuCode.maxInputLength + 1),
                  bytes.count <= MenuCode.maxInputLength else { return nil }
            return String(data: bytes, encoding: .utf8)
        }.value
        if let input {
            setCode(input)
        } else {
            text = ""
            status = "import.fileError"
            importedCount = nil
        }
    }
}
