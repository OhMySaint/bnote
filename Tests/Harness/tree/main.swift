import AppKit
import SwiftData

setvbuf(stdout, nil, _IOLBF, 0)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
var failures: [String] = []
func check(_ label: String, _ ok: Bool, _ detail: String = "") { print(ok ? "  ok   \(label)" : "  FAIL \(label) \(detail)"); if !ok { failures.append(label) } }
func pump(_ s: TimeInterval = 0.05) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

// MARK: - Content (English screenplay, one page per act, one page per scene)

let actionPool = [
    "Rain hammers the window. Red neon bleeds across the wet tabletop.",
    "She sits upright, both hands around a cup of tea that went cold an hour ago, eyes fixed on the door.",
    "A train whistle, far off. A cat leaps from a bin and vanishes into the dark.",
    "He comes in, coat soaked through, a creased envelope in his hand.",
    "The wall clock has stopped at 11:47. Nobody notices.",
    "The camera drifts across the faces in the café: tired, waiting, pretending not to listen.",
    "Outside, the last train of the night slides past, its lit windows sweeping the ceiling.",
    "She laughs, then stops, as if she has just remembered something.",
    "His hand shakes, only slightly, as he sets the envelope down.",
    "A waiter passes and leaves the bill without a word.",
    "The platform lights flicker twice and hold.",
    "Somewhere a radio plays a song neither of them will admit to knowing.",
]
let linePool = [
    "You're late.", "The train stopped at Binh Trieu. I walked.", "I didn't ask about the train.",
    "What is it?", "Read it and you'll know.", "I won't read what you won't say out loud.",
    "It isn't that I won't.", "Then what?", "I haven't found the way to say it.",
    "Any way is fine, as long as it's true.", "True hurts.", "Not knowing hurts more.",
    "My father called yesterday.", "What did he say?", "He asked when you're coming home.",
    "I don't know yet.", "I do.", "Then tell me.", "Ninety minutes. That's what we have.",
    "You counted?", "I always count.",
]
let placePool = ["INT. STATION CAFÉ — NIGHT", "EXT. BINH TRIEU PLATFORM — RAIN", "INT. LINH'S APARTMENT — MORNING", "EXT. RIVERBANK — DUSK", "INT. CITY BUS — NOON", "INT. MR. TU'S HOUSE — EVENING", "EXT. NIGHT MARKET — NIGHT", "INT. HOSPITAL CORRIDOR — DAWN"]
let characters = ["LINH", "MINH", "MRS. HOA", "MR. TU", "TAI"]
var seed: UInt64 = 11
func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
func action(_ n: Int) -> String { (0..<n).map { _ in actionPool[rnd(actionPool.count)] }.joined(separator: " ") }

enum Block { case title(String), h1(String), h2(String), h3(String), body(String), bullets([String]), numbers([String]), quote(String), callout(String), todo([String]), character(String), dialogue(String), parenthetical(String), link(String, URL) }

let controller = DocumentController.shared
let host = EditorCanvasView(controller: controller)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = host; host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); window.orderFront(nil)
Defaults.register()
controller.canvasOptions = Defaults.canvasOptions

/// Builds one page's document through the editor and returns its archive + plain text + page count.
func build(_ blocks: [Block]) -> (Data, String, Int) {
    controller.load(data: nil, plainText: "", config: Defaults.pageConfig); pump()
    let tv = controller.activeTextView!
    window.makeFirstResponder(tv)
    for block in blocks {
        let start = controller.textStorage.length
        func put(_ text: String) { tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0)); controller.insertPlainText(text + "\n") }
        func select() { tv.setSelectedRange(NSRange(location: start, length: max(0, controller.textStorage.length - start - 1))) }
        switch block {
        case .title(let t): put(t); select(); controller.apply(style: .title)
        case .h1(let t): put(t); select(); controller.apply(style: .heading1)
        case .h2(let t): put(t); select(); controller.apply(style: .heading2)
        case .h3(let t): put(t); select(); controller.apply(style: .heading3)
        case .body(let t): put(t); select(); controller.apply(style: .body)
        case .bullets(let items): put(items.joined(separator: "\n")); select(); controller.apply(style: .body); controller.toggleList(.bullet)
        case .numbers(let items): put(items.joined(separator: "\n")); select(); controller.apply(style: .body); controller.toggleList(.numbered)
        case .todo(let items): put(items.joined(separator: "\n")); select(); controller.apply(style: .body); controller.toggleList(.todo)
        case .quote(let t): put(t); select(); controller.apply(style: .body); tv.setSelectedRange(NSRange(location: start, length: 0)); controller.insertQuote()
        case .callout(let t): put(t); select(); controller.apply(style: .body); tv.setSelectedRange(NSRange(location: start, length: 0)); controller.insertCallout()
        case .character(let t): put(t); select(); controller.apply(style: .body); controller.toggleTrait(.boldFontMask); controller.setAlignment(.center)
        case .dialogue(let t): put(t); select(); controller.apply(style: .body); controller.changeIndent(by: EditorDefaults.tabIndent * 2)
        case .parenthetical(let t): put(t); select(); controller.apply(style: .body); controller.toggleTrait(.italicFontMask); controller.changeIndent(by: EditorDefaults.tabIndent * 3)
        case .link(let title, let url): tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0)); controller.insertPageLink(title: title, url: url)
        }
        tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
        tv.typingAttributes = EditorDefaults.bodyAttributes
    }
    pump(); host.canvas.updatePagination()
    let snap = controller.snapshot()
    return (snap.data, snap.plainText, controller.pageCount)
}

// MARK: - Write the tree into the app's store

let storeURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Containers/com.hoangson.BNote/Data/Library/Application Support/default.store")
do {
    let container = try ModelContainer(for: Note.self, Tag.self, configurations: ModelConfiguration(url: storeURL))
    try MainActor.assumeIsolated {
        let context = container.mainContext
        let existing = try context.fetch(FetchDescriptor<Note>())
        // Replace the earlier single-document screenplay (and its empty scratch child).
        for old in existing where old.title.hasPrefix("[Test] Kịch bản") || old.title.hasPrefix("[Test] Screenplay") {
            context.delete(old)
        }
        let nextIndex = (existing.map(\.sortIndex).max() ?? 0) + 1
        let config = Defaults.pageConfig

        let root = Note(title: "[Test] Screenplay — The Last Train", sortIndex: nextIndex)
        root.icon = "🎬"; root.tags = ["screenplay", "test"]; root.coverStyle = CoverStyle.slate.rawValue
        root.subtitle = "Three acts, one night, ninety minutes before the last train"
        root.pageConfig = config
        context.insert(root)

        let acts = [("Act I — Ninety Minutes", 8), ("Act II — The Envelope", 10), ("Act III — The Last Train", 8)]
        var sceneNo = 0
        var totalPages = 0
        var actNotes: [Note] = []
        for (ai, (actTitle, sceneCount)) in acts.enumerated() {
            let act = Note(title: actTitle, parent: root, sortIndex: ai + 1)
            act.icon = ["1️⃣", "2️⃣", "3️⃣"][ai]; act.pageConfig = config; act.tags = ["screenplay"]
            context.insert(act)
            actNotes.append(act)

            var sceneNotes: [Note] = []
            for si in 0..<sceneCount {
                sceneNo += 1
                let place = placePool[rnd(placePool.count)]
                let scene = Note(title: "Scene \(sceneNo) — \(place.capitalized)", parent: act, sortIndex: si + 1)
                scene.icon = "🎞️"; scene.pageConfig = config
                context.insert(scene)
                sceneNotes.append(scene)

                var blocks: [Block] = [.h1("SCENE \(sceneNo)"), .h2(place), .body(action(4))]
                for _ in 0..<(6 + rnd(4)) {
                    blocks.append(.character(characters[rnd(2)]))
                    if rnd(3) == 0 { blocks.append(.parenthetical(["(beat)", "(not looking at him)", "(a thin smile)", "(after a moment)"][rnd(4)])) }
                    blocks.append(.dialogue(linePool[rnd(linePool.count)]))
                }
                blocks.append(.body(action(3)))
                if sceneNo % 5 == 0 { blocks.append(.callout("Director's note: one continuous take, no cuts, following Linh from the counter to the platform.")) }
                if sceneNo % 7 == 0 { blocks.append(.todo(["Trim two lines of dialogue", "Check continuity: the coat from Scene 1"])) }
                blocks.append(.h3("Transition")); blocks.append(.body("CUT TO:"))
                let (data, text, pages) = build(blocks)
                scene.rtfData = data; scene.content = text; totalPages += pages
            }

            // Act page: summary + links to its scenes.
            var actBlocks: [Block] = [.title(actTitle), .body(action(3)), .h2("Scenes")]
            for s in sceneNotes { actBlocks.append(.link(s.title, s.linkURL)) }
            let (adata, atext, apages) = build(actBlocks)
            act.rtfData = adata; act.content = atext; totalPages += apages
        }

        // Root page: logline, characters, notes, links to acts.
        var rootBlocks: [Block] = [
            .title("THE LAST TRAIN"),
            .body("Feature screenplay · Third draft · Written by Hoang Son"),
            .callout("Logline: On a rainy night at Binh Trieu station, two people who used to be in love have exactly ninety minutes before the last train to decide whether to tell the truth."),
            .h1("Characters"),
            .bullets(["LINH — 29, an editor. Says little, remembers everything.", "MINH — 31, a railway engineer. Always late.", "MRS. HOA — owns the station café and knows more than she says.", "MR. TU — Linh's father, in hospital.", "TAI — Minh's friend, appears in Act III."]),
            .h1("Director's notes"),
            .quote("The whole film takes place in one night. No score until the final scene."),
            .todo(["Lock the ending with the producer", "Clear the song rights for Scene 14", "Cut three pages from Act II"]),
            .h1("Acts"),
        ]
        for a in actNotes { rootBlocks.append(.link(a.title, a.linkURL)) }
        let (rdata, rtext, rpages) = build(rootBlocks)
        root.rtfData = rdata; root.content = rtext; totalPages += rpages

        TagStore.ensure("screenplay", in: context)?.color = .red
        TagStore.ensure("test", in: context)
        try context.save()
        print("  pages written: 1 root + \(acts.count) acts + \(sceneNo) scenes · \(totalPages) printed pages in total")
        check("tree written", true)
        check("~20 printed pages", totalPages >= 18 && totalPages <= 40, "got \(totalPages)")
        check("root links to acts", rtext.contains("📄 Act I") && rtext.contains("📄 Act III"))
    }
} catch {
    check("tree written", false, "\(error)")
}
print(failures.isEmpty ? "\nALL PASSED" : "\nFAILED (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
