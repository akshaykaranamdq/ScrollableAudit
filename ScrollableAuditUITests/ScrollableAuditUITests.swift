//
//  ScrollableAuditUITests.swift
//  ScrollableAuditUITests
//
//  Basic scroll-coverage check on the original 20-row list, using the
//  A11yScrollAudit package (add it to this UI-test target: File > Add Package
//  Dependencies > Add Local > A11yScrollAudit). The rule-by-rule accuracy
//  tests are in ProductionScreenAccuracyTests.
//

import XCTest
import A11yScrollAudit

@MainActor
final class ScrollableAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Full-list contrast audit. Row 7 has a seeded low-contrast label.
    func testContrast_wholeList() throws {
        let app = XCUIApplication()
        app.launchEnvironment["AUDIT_SCREEN"] = "legacy"   // open the 20-row list directly
        app.launch()

        var options = A11yScrollAudit.Options(auditTypes: .contrast)
        options.attachScreenshots = false
        let report = try A11yScrollAudit.run(app: app, name: "Legacy list", options: options)

        // A page may time out, as long as overlap meant every item was audited elsewhere.
        XCTAssertTrue(report.unauditedItems.isEmpty, "Items never audited: \(report.unauditedItems)")
        XCTAssertTrue(report.itemsCovered.contains("row_20"), "Never scrolled to the last row")

        // Apple reports two severities: "Contrast failed" and "Contrast nearly
        // passed". The second is not a pass: the system-blue "Open" buttons
        // (4.02:1) really are under WCAG AA's 4.5:1. This test only asserts the
        // SEVERE case, that row 7 is the one element reported as "failed".
        let contrast = report.findings(ofType: "contrast")
        let failures = contrast.filter { !$0.summary.localizedCaseInsensitiveContains("nearly passed") }
        let warnings = contrast.filter { $0.summary.localizedCaseInsensitiveContains("nearly passed") }
        print("contrast failures: \(failures.count), warnings (nearly passed): \(warnings.count)")

        // Row 7 is the only seeded contrast defect; nothing else should fail.
        let culprits = failures.compactMap { $0.resolvedElement }
        XCTAssertEqual(culprits, ["row_7"], "Expected only row_7. Got: \(failures)")
    }
}
