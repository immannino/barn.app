import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings → looks: pick a look, tweak your own, and trade them as JSON.
struct LooksPane: View {
    @ObservedObject var settings: Settings
    @State private var state: AgentState = .waiting
    @State private var message: (text: String, isError: Bool)?
    @State private var confirmingDelete = false

    private var savedIndex: Int? { settings.looks.firstIndex { $0.id == settings.activeLookID } }
    private var look: Look { settings.activeLook }

    var body: some View {
        VStack(spacing: 0) {
            // Pinned above the scrolling controls so every change shows while you make it.
            LookPreview(look: look)
                .padding([.horizontal, .top], 24)
            content
        }
        .onChange(of: settings.activeLookID) { confirmingDelete = false }
    }

    private var content: some View {
        Pane {
            SectionTitle(text: "the deck")
            DeckOptions(settings: settings)
            SectionTitle(text: "how cards look in each state")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Look.presets, id: \.name) { preset in
                    chip(preset, id: Settings.presetID(preset))
                }
                ForEach(settings.looks) { saved in
                    chip(saved.look, id: saved.id)
                }
            }
            actions
            if let message {
                Text(message.text)
                    .font(.system(size: 12))
                    .foregroundStyle(message.isError ? Color(nsColor: Brand.coral) : .secondary)
            }
            if let i = savedIndex {
                LookEditor(look: $settings.looks[i].look, state: $state)
            } else {
                Text("This is one of barn's presets. Duplicate it to make your own and change anything.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chip(_ look: Look, id: String) -> some View {
        let active = settings.activeLookID == id
        return Button { settings.activeLookID = id } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(AgentState.allCases, id: \.self) { s in
                        Circle().fill(look.style(for: s).swiftColor).frame(width: 9, height: 9)
                    }
                    Spacer(minLength: 0)
                    if active { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                }
                Text(look.name)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(look.author.map { "by \($0)" } ?? "yours")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(active ? Brand.blue.opacity(0.14) : Color.secondary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(active ? Brand.blue.opacity(0.6) : .clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(savedIndex == nil ? "duplicate to edit" : "duplicate") { duplicate() }
                .buttonStyle(.borderedProminent)
            Button("copy JSON") { copy() }
                .help("copy this look to share it")
            Button("paste") { paste() }
                .help("add a look someone shared with you, from the clipboard")
            Menu("more") {
                Button("import from file…") { importFile() }
                Button("export to file…") { exportFile() }
            }
            .fixedSize()
            Spacer()
            if savedIndex != nil {
                if confirmingDelete {
                    Button("delete \(look.name)", role: .destructive) { delete() }
                        .foregroundStyle(Color(nsColor: Brand.coral))
                } else {
                    Button("delete") { confirmingDelete = true }
                }
            }
        }
        .controlSize(.small)
    }

    // MARK: Actions

    private func add(_ look: Look) {
        var look = look
        let names = Set(Look.presets.map(\.name) + settings.looks.map(\.look.name))
        if names.contains(look.name) {
            let base = look.name
            var n = 2
            while names.contains("\(base) \(n)") { n += 1 }
            look.name = "\(base) \(n)"
        }
        let saved = SavedLook(id: UUID().uuidString, look: look)
        settings.looks.append(saved)
        settings.activeLookID = saved.id
    }

    private func duplicate() {
        var copy = look
        copy.author = nil
        add(copy)
        message = ("made a copy you can edit", false)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(look.json, forType: .string)
        message = ("copied \(look.name) as JSON. paste it anywhere: a chat, a gist, an issue.", false)
    }

    private func paste() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            message = ("the clipboard has no text", true)
            return
        }
        load(text)
    }

    private func load(_ text: String) {
        do {
            let look = try Look.parse(text)
            add(look)
            message = ("added \(look.name)\(look.author.map { " by \($0)" } ?? "") and turned it on", false)
        } catch {
            message = (error.localizedDescription, true)
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            message = ("couldn't read \(url.lastPathComponent)", true)
            return
        }
        load(text)
    }

    private func exportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(look.name).json"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try look.json.write(to: url, atomically: true, encoding: .utf8)
            message = ("saved \(url.lastPathComponent)", false)
        } catch {
            message = ("couldn't save: \(error.localizedDescription)", true)
        }
    }

    private func delete() {
        guard let i = savedIndex else { return }
        let name = settings.looks[i].look.name
        settings.activeLookID = Settings.presetID(.barn)
        settings.looks.remove(at: i)
        message = ("deleted \(name)", false)
    }
}

/// Layout, size, font and opacity for the deck. Yours alone: not part of a shared look.
private struct DeckOptions: View {
    @ObservedObject var settings: Settings
    @State private var choosingFont = false

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                label("layout")
                Picker("layout", selection: $settings.deckLayout) {
                    Label("cards", systemImage: "square.grid.2x2").tag(DeckLayout.tiles)
                    Label("list", systemImage: "list.bullet").tag(DeckLayout.list)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            GridRow {
                label("size")
                Picker("size", selection: $settings.deckSize) {
                    ForEach(DeckSize.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 260)
            }
            GridRow {
                label("font")
                HStack(spacing: 10) {
                    Picker("font", selection: $settings.deckFont) {
                        ForEach(DeckFont.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 300)
                    if settings.deckFont == .custom {
                        Button(settings.deckFontFamily.isEmpty ? "choose…" : settings.deckFontFamily) { choosingFont = true }
                            .controlSize(.small)
                            .popover(isPresented: $choosingFont, arrowEdge: .bottom) {
                                FontFamilyList(selection: $settings.deckFontFamily) { choosingFont = false }
                            }
                    }
                }
            }
            GridRow {
                label("opacity")
                HStack(spacing: 10) {
                    Slider(value: $settings.deckOpacity, in: 0.25...1).frame(maxWidth: 200)
                    Text(settings.deckOpacity >= 0.99 ? "solid" : "\(Int((settings.deckOpacity * 100).rounded()))% until you point at it")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if settings.deckLayout == .tiles {
                GridRow {
                    label("per row")
                    Stepper("\(settings.deckColumns) cards", value: $settings.deckColumns, in: 1...8).fixedSize()
                }
            }
        }
        .onChange(of: settings.deckFont) {
            if settings.deckFont == .custom && settings.deckFontFamily.isEmpty { choosingFont = true }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
    }
}

/// Every installed font family, each shown in itself, with search.
private struct FontFamilyList: View {
    @Binding var selection: String
    var done: () -> Void
    @State private var query = ""
    private static let families = NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") }

    var body: some View {
        let shown = query.isEmpty ? Self.families
            : Self.families.filter { $0.localizedCaseInsensitiveContains(query) }
        VStack(spacing: 8) {
            TextField("search \(Self.families.count) fonts", text: $query)
                .textFieldStyle(.roundedBorder)
            ScrollViewReader { proxy in
                List(shown, id: \.self) { family in
                    Button {
                        selection = family
                        done()
                    } label: {
                        HStack {
                            Text(family).font(.custom(family, size: 14)).lineLimit(1)
                            Spacer()
                            if family == selection { Image(systemName: "checkmark").foregroundStyle(Brand.blue) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .id(family)
                }
                .listStyle(.plain)
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
            }
        }
        .padding(12)
        .frame(width: 280, height: 360)
    }
}

/// One sample agent per state, on barn's backdrop, in the deck's current layout and size, scaled
/// down when it wouldn't fit.
private struct LookPreview: View {
    var look: Look
    @ObservedObject private var settings = Settings.shared
    static let maxSize = CGSize(width: 552, height: 132)

    var body: some View {
        let m = DeckMetrics.current
        let list = settings.deckLayout == .list
        let natural = list
            ? CGSize(width: m.rowWidth * 2 + m.spacing, height: m.rowHeight * 2 + m.spacing)
            : CGSize(width: m.tileSize * 4 + m.spacing * 3, height: m.tileSize)
        let fit = min(1, (Self.maxSize.width - 40) / natural.width, (Self.maxSize.height - 28) / natural.height)
        Group {
            if list {
                Grid(horizontalSpacing: m.spacing, verticalSpacing: m.spacing) {
                    GridRow { row(.waiting); row(.ready) }
                    GridRow { row(.working); row(.idle) }
                }
            } else {
                HStack(spacing: m.spacing) {
                    ForEach(AgentState.allCases, id: \.self) { DeckTile(agent: Self.sample($0), look: look) }
                }
            }
        }
        .scaleEffect(fit)
        .frame(width: natural.width * fit, height: natural.height * fit)
        .frame(maxWidth: .infinity)
        .frame(height: Self.maxSize.height)
        .background(BrandBackdrop().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
        .opacity(settings.deckOpacity)
        .environment(\.colorScheme, .dark)
    }

    private func row(_ state: AgentState) -> some View {
        DeckRow(agent: Self.sample(state), look: look)
            .help("\(Self.sample(state).displayTitle)\n\(statusLine(Self.sample(state)))")
    }

    private static func sample(_ state: AgentState) -> Agent {
        let (project, detail): (String, String?) = switch state {
        case .waiting: ("pancake-api", "permission · Bash: npm run migrate")
        case .ready: ("garden", nil)
        case .working: ("web", "Edit: Onboarding.tsx")
        case .idle: ("docs", nil)
        }
        return Agent(pid: pid_t(900 + state.rawValue), kind: .claude, cwd: "/barn/\(project)", tty: nil, host: nil,
                     state: state, stateSince: Date().addingTimeInterval(-120), title: nil, detail: detail, precise: true)
    }
}

/// Edits one state of a saved look at a time.
private struct LookEditor: View {
    @Binding var look: Look
    @Binding var state: AgentState

    private var style: Binding<StateStyle> {
        Binding(get: { look[state] }, set: { look[state] = $0.clamped() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("name", text: Binding(get: { look.name }, set: { look.name = String($0.prefix(40)) }))
                TextField("author (shown when you share it)", text: Binding(
                    get: { look.author ?? "" },
                    set: { look.author = $0.isEmpty ? nil : String($0.prefix(40)) }))
            }
            .textFieldStyle(.roundedBorder)

            Picker("state", selection: $state) {
                ForEach(AgentState.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 18) {
                ColorPicker(style.wrappedValue.darkColor == nil ? "color" : "light", selection: Binding(
                    get: { Color(nsColor: style.wrappedValue.resolved(dark: false)) },
                    set: { style.wrappedValue.color = NSColor($0).hex }), supportsOpacity: false)
                if style.wrappedValue.darkColor != nil {
                    ColorPicker("dark", selection: Binding(
                        get: { Color(nsColor: style.wrappedValue.resolved(dark: true)) },
                        set: { style.wrappedValue.darkColor = NSColor($0).hex }), supportsOpacity: false)
                }
                labeled("tint") { Slider(value: style.tint, in: 0...1) }
            }
            Toggle("a different color in dark mode", isOn: Binding(
                get: { style.wrappedValue.darkColor != nil },
                set: { style.wrappedValue.darkColor = $0 ? style.wrappedValue.color : nil }))
                .font(.system(size: 12))
            if style.wrappedValue.isSolid {
                Text("This tint is strong enough to look solid, so the card's text switches to black or white to stay readable.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("effects").font(.system(size: 12, weight: .medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(Effect.allCases, id: \.self) { effect in effectChip(effect) }
                }
                if style.wrappedValue.effects.contains(where: { $0 == .flash || $0 == .strobe }) {
                    Text("Flashing never goes faster than 3 times a second. With Reduce Motion on, every effect holds still.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 18) {
                labeled("speed") { Slider(value: style.speed, in: StateStyle.speedRange) }
                labeled("intensity") { Slider(value: style.intensity, in: 0...1) }
            }
            .disabled(style.wrappedValue.effects.isEmpty)

            Button("reset \(state.label) to barn's") { look[state] = Look.barn[state] }
                .controlSize(.small)
        }
    }

    private func effectChip(_ effect: Effect) -> some View {
        let on = style.wrappedValue.effects.contains(effect)
        return Button {
            var s = style.wrappedValue
            if on { s.effects.removeAll { $0 == effect } } else { s.effects.append(effect) }
            style.wrappedValue = s
        } label: {
            Text(effect.label)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .foregroundStyle(on ? .white : .primary)
                .background(Capsule().fill(on ? Brand.blue : Color.secondary.opacity(0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(effect.help)
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            content()
        }
    }
}
