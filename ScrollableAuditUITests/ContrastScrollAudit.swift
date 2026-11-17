//
//  ContrastScrollAudit.swift
//
//  DROP-IN, APP-AGNOSTIC. Copy this single file into any UI Testing target.
//  No app code, identifiers or accessibility changes are required.
//
//  Apple's `performAccessibilityAudit` only inspects what is on screen. This
//  helper scrolls the main scrollable container (List / table / collection /
//  scroll view) one overlapping step at a time and runs the COLOUR CONTRAST
//  audit on every step, then merges the results.
//
//  Usage:
//      let app = XCUIApplication(); app.launch()
//      // navigate to the screen under test, then:
//      let result = try ContrastScrollAudit.run(app: app)
//      XCTAssertTrue(result.findings.isEmpty, "\(result.findings)")
//
//  Requirements: Xcode 15+, iOS 17+ simulator/device, UI Testing target.
//

import XCTest

@MainActor
enum ContrastScrollAudit {

    // MARK: - Public API

    struct Options {
        /// Safety cap for very long or endless (paginated) lists.
        var maxPages = 40
        /// Scroll distance per step as a fraction of the container height.
        /// Smaller = more overlap = tighter localisation, but more audits.
        var stepFraction: CGFloat = 0.15
        /// Retries per page when Apple's audit throws "failed to complete in time".
        var attempts = 4
        /// An item counts as on-screen when at least this much of it is visible.
        var visibleRatio: CGFloat = 0.9
        /// Attach a screenshot to the test report for every page with findings.
        var attachScreenshots = true
        /// Print progress and the final report to the console.
        var verbose = true
    }

    struct Finding: CustomStringConvertible {
        /// Apple's short description of the issue.
        let summary: String
        /// Apple's long description (often includes the measured ratio).
        let detail: String
        /// Set when the audit resolved the offending element itself.
        let element: String?
        /// On-screen items this issue can belong to, narrowed by page overlap.
        /// One entry means the culprit is pinned down exactly.
        let candidates: [String]
        /// Scroll pages (0-based) on which the issue was reported.
        let pages: [Int]

        var description: String {
            let where_: String
            if let element {
                where_ = "\(element) (exact)"
            } else if candidates.isEmpty {
                where_ = "unlocalised"
            } else {
                where_ = candidates.joined(separator: ", ")
                    + (candidates.count == 1 ? " (exact)" : " (narrowed)")
            }
            return "contrast | \(where_) | pages \(pages) | \(summary)"
        }
    }

    struct Result {
        /// Contrast issues that held up across every page their item was visible on.
        let findings: [Finding]
        /// Issues reported only while an item was clipped at a screen/bar edge.
        /// Not real defects; kept so you can inspect what was discarded.
        let edgeArtifacts: [Finding]
        let pagesAudited: Int
        /// Every item (identifier, else label) that was fully on screen at least once.
        let itemsCovered: Set<String>
        /// Items that only ever appeared on pages whose audit never completed.
        /// Empty means every item was audited at least once.
        let unauditedItems: Set<String>
        /// Pages where the audit never completed even after retries.
        let incompletePages: [Int]
    }

    /// Scrolls `container` (auto-detected when nil) and audits contrast on each step.
    /// With no scrollable container on screen, audits the single visible screen.
    @discardableResult
    static func run(app: XCUIApplication,
                    container: XCUIElement? = nil,
                    options: Options = Options()) throws -> Result {

        let scroller = container ?? findScrollContainer(in: app)
        var pages: [Page] = []
        var covered = Set<String>()

        for index in 0..<options.maxPages {
            if let scroller { waitForSettle(scroller, app: app, options: options) }

            // Snapshot the viewport BEFORE auditing: the audit takes a while and
            // an item list read afterwards may already have moved.
            let items = scroller.map { visibleItems(in: $0, app: app, options: options) } ?? []
            let signature = items.map { "\($0.key)@\($0.minY)" }.sorted().joined(separator: ",")

            // End of list: the previous scroll moved nothing.
            if let last = pages.last, scroller != nil, last.signature == signature { break }

            let issues = auditContrast(app: app, page: index, options: options)
            pages.append(Page(index: index, items: Set(items.map(\.key)),
                              signature: signature, issues: issues))
            covered.formUnion(items.map(\.key))

            if options.verbose {
                print("[contrast page \(index)] items: \(items.map(\.key)) issues: "
                      + (issues.map { String($0.count) } ?? "AUDIT INCOMPLETE"))
            }
            if options.attachScreenshots, let issues, !issues.isEmpty {
                attachScreenshot(of: app, named: "contrast-page-\(index)")
            }

            guard let scroller else { break }          // nothing to scroll
            scrollOneStep(scroller, options: options)
        }

        let localised = localise(pages)
        let auditedItems = pages.filter { $0.issues != nil }
            .reduce(into: Set<String>()) { $0.formUnion($1.items) }
        let result = Result(findings: localised.confirmed,
                            edgeArtifacts: localised.transient,
                            pagesAudited: pages.count,
                            itemsCovered: covered,
                            unauditedItems: covered.subtracting(auditedItems),
                            incompletePages: pages.filter { $0.issues == nil }.map(\.index))
        if options.verbose { printReport(result) }
        return result
    }

    // MARK: - Models

    private struct RawIssue {
        let summary: String
        let detail: String
        let element: String?
        var key: String { "\(summary)|\(element ?? "-")" }
    }

    private struct Page {
        let index: Int
        let items: Set<String>
        let signature: String
        let issues: [RawIssue]?   // nil = audit never completed on this page
    }

    private struct Item {
        let key: String
        let minY: Int
    }

    // MARK: - Auditing

    /// One contrast audit with retries. Returns nil if it never completed.
    private static func auditContrast(app: XCUIApplication,
                                      page: Int,
                                      options: Options) -> [RawIssue]? {
        for attempt in 1...options.attempts {
            var batch: [RawIssue] = []
            do {
                try app.performAccessibilityAudit(for: .contrast) { issue in
                    let id = issue.element?.identifier ?? ""
                    let label = issue.element?.label ?? ""
                    let name = !id.isEmpty ? id : label
                    batch.append(RawIssue(summary: issue.compactDescription,
                                          detail: issue.detailedDescription,
                                          element: name.isEmpty ? nil : name))
                    return true   // handled: keep going, we report at the end
                }
                return batch      // only a complete run is trusted
            } catch {
                if options.verbose {
                    print("[contrast page \(page)] attempt \(attempt) failed: \(error)")
                }
                Thread.sleep(forTimeInterval: 2.0)   // let the app go idle, then retry
            }
        }
        return nil
    }

    // MARK: - Localisation

    /// Narrows each distinct issue to the items it can belong to.
    ///
    /// For SwiftUI the audit usually returns no element for contrast issues, so
    /// overlap is used instead: the culprit is on screen on every page that
    /// reported the issue, and absent from every page that did not.
    ///
    /// Then a persistence check weeds out edge artifacts: an item that was fully
    /// visible on a page where the issue was NOT reported cannot really have it.
    /// (Rows half-hidden under a bar or at the screen edge get flagged on the
    /// one page where they are clipped, and nowhere else.)
    private static func localise(_ allPages: [Page]) -> (confirmed: [Finding], transient: [Finding]) {
        // Pages whose audit never completed say nothing either way.
        let pages = allPages.filter { $0.issues != nil }

        var order: [String] = []
        var sample: [String: RawIssue] = [:]
        var offsets: [String: [Int]] = [:]   // positions within `pages`

        for (offset, page) in pages.enumerated() {
            for issue in page.issues ?? [] {
                if sample[issue.key] == nil { sample[issue.key] = issue; order.append(issue.key) }
                if offsets[issue.key]?.last != offset { offsets[issue.key, default: []].append(offset) }
            }
        }

        var confirmed: [Finding] = []
        var transient: [Finding] = []

        for key in order {
            let issue = sample[key]!
            // One defect = one contiguous run of pages. A gap means a second
            // defect with the same message, so each run is localised separately.
            for run in contiguousRuns(offsets[key] ?? []) {
                let hits = Set(run)
                var candidates: Set<String>? = nil
                for offset in run {
                    candidates = candidates.map { $0.intersection(pages[offset].items) } ?? pages[offset].items
                }
                var result = candidates ?? []
                for (offset, page) in pages.enumerated() where !hits.contains(offset) {
                    result.subtract(page.items)
                }
                let finding = Finding(summary: issue.summary,
                                      detail: issue.detail,
                                      element: issue.element,
                                      candidates: result.sorted(by: naturalOrder),
                                      pages: run.map { pages[$0].index })

                // Persistence check for findings the audit pinned to an element.
                var isTransient = false
                if let element = issue.element {
                    isTransient = pages.enumerated().contains { offset, page in
                        page.items.contains(element) && !hits.contains(offset)
                    }
                }
                if isTransient { transient.append(finding) } else { confirmed.append(finding) }
            }
        }
        return (confirmed, transient)
    }

    /// `[0, 1, 2, 5, 6]` -> `[[0, 1, 2], [5, 6]]`
    private static func contiguousRuns(_ values: [Int]) -> [[Int]] {
        values.sorted().reduce(into: [[Int]]()) { runs, value in
            if let last = runs.last?.last, value == last + 1 {
                runs[runs.count - 1].append(value)
            } else {
                runs.append([value])
            }
        }
    }

    // MARK: - Viewport

    /// Items fully (>= visibleRatio) on screen, from ONE accessibility snapshot
    /// of the container - far faster than querying each element separately.
    private static func visibleItems(in container: XCUIElement,
                                     app: XCUIApplication,
                                     options: Options) -> [Item] {
        guard let snapshot = try? container.snapshot() else { return [] }

        // The container extends under translucent bars; items beneath them are
        // not really visible, so shrink the viewport to the space between bars.
        var viewport = snapshot.frame
        let nav = app.navigationBars.firstMatch
        if nav.exists, nav.frame.maxY > viewport.minY {
            let cut = nav.frame.maxY - viewport.minY
            viewport = CGRect(x: viewport.minX, y: viewport.minY + cut,
                              width: viewport.width, height: viewport.height - cut)
        }
        let tab = app.tabBars.firstMatch
        if tab.exists, tab.frame.minY < viewport.maxY {
            viewport.size.height = max(0, tab.frame.minY - viewport.minY)
        }

        var items: [Item] = []
        for child in snapshot.children {
            collect(child, viewport: viewport, ratio: options.visibleRatio, into: &items)
        }
        return items
    }

    private static let structural: Set<XCUIElement.ElementType> = [
        .window, .application, .scrollView, .table, .collectionView,
        .navigationBar, .tabBar, .statusBar, .keyboard, .scrollBar
    ]

    /// Collects the most specific labelled/identified element on each branch, so
    /// a row is represented by its text, not by both the row and the text.
    @discardableResult
    private static func collect(_ node: XCUIElementSnapshot,
                                viewport: CGRect,
                                ratio: CGFloat,
                                into items: inout [Item]) -> Bool {
        var foundBelow = false
        for child in node.children {
            if collect(child, viewport: viewport, ratio: ratio, into: &items) { foundBelow = true }
        }
        if foundBelow { return true }

        guard !structural.contains(node.elementType) else { return false }
        let name = !node.identifier.isEmpty ? node.identifier : node.label
        guard !name.isEmpty else { return false }
        // The system scroll indicator is not content, and its label changes.
        guard !name.hasPrefix("Vertical scroll bar"),
              !name.hasPrefix("Horizontal scroll bar") else { return false }

        let frame = node.frame
        guard frame.width > 0, frame.height > 0 else { return false }
        let visible = frame.intersection(viewport)
        guard !visible.isNull,
              (visible.width * visible.height) / (frame.width * frame.height) >= ratio else { return false }

        items.append(Item(key: name, minY: Int(frame.minY)))
        return true
    }

    // MARK: - Scrolling

    private static func findScrollContainer(in app: XCUIApplication) -> XCUIElement? {
        let candidates = app.collectionViews.allElementsBoundByIndex
            + app.tables.allElementsBoundByIndex
            + app.scrollViews.allElementsBoundByIndex
        return candidates
            .filter { $0.exists && !$0.frame.isEmpty }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }

    private static func scrollOneStep(_ container: XCUIElement, options: Options) {
        let startY: CGFloat = 0.80
        let endY = max(0.05, startY - options.stepFraction)
        let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        // Slow drag + hold at the end kills flick inertia, so the content travels
        // the distance asked for and nothing gets scrolled past unaudited.
        start.press(forDuration: 0.1, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// Polls until two consecutive samples agree, so the audit never runs on a
    /// mid-animation frame.
    private static func waitForSettle(_ container: XCUIElement,
                                      app: XCUIApplication,
                                      options: Options,
                                      timeout: TimeInterval = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        var previous = ""
        while Date() < deadline {
            let signature = visibleItems(in: container, app: app, options: options)
                .map { "\($0.key)@\($0.minY)" }.sorted().joined(separator: ",")
            if signature == previous { return }
            previous = signature
            Thread.sleep(forTimeInterval: 0.15)
        }
    }

    // MARK: - Reporting

    private static func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: name) { $0.add(attachment) }
    }

    private static func printReport(_ result: Result) {
        print("\n=== CONTRAST SCROLL AUDIT ===")
        print("pages audited: \(result.pagesAudited)")
        print("items covered (\(result.itemsCovered.count)): \(result.itemsCovered.sorted(by: naturalOrder))")
        if !result.incompletePages.isEmpty {
            print("pages where the audit never completed: \(result.incompletePages)")
            print("items never audited on any page: \(result.unauditedItems.sorted(by: naturalOrder))")
        }
        print("contrast findings: \(result.findings.count)")
        result.findings.forEach { print("  \($0)") }
        if !result.edgeArtifacts.isEmpty {
            print("discarded as edge artifacts (clipped at a bar/screen edge): \(result.edgeArtifacts.count)")
            result.edgeArtifacts.forEach { print("  \($0)") }
        }
    }

    /// Sorts "row_2" before "row_10".
    private static func naturalOrder(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedAscending
    }
}
