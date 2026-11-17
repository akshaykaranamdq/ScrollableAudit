//
//  ProductionScreenAccuracyTests.swift
//
//  Measures how accurate Apple's accessibility audit is, rule by rule, on
//  production-style screens. YOU choose the rules:
//
//    * one rule      run testAccuracy_<rule>, e.g. testAccuracy_hitRegion
//    * every rule    run testAccuracy_allRules
//    * any mix       run testAccuracy_selectedRules after setting the
//                    AUDIT_RULES environment variable (Edit Scheme > Test >
//                    Arguments > Environment Variables), for example
//                        AUDIT_RULES = contrast, hitRegion, dynamicType
//                    or AUDIT_RULES = all. Unset means all rules.
//
//  Rule names: contrast, elementDetection, hitRegion,
//  sufficientElementDescription (alias elementDescription), dynamicType,
//  textClipped, trait.
//
//  How it grades. Every element in the app is built from a spec in Shared/, so
//  the correct answer for each (element, rule) pair is known up front: contrast
//  is computed from the WCAG formula, and the other rules follow from how the
//  control is built (target size, accessible name, scaling font, truncation,
//  traits). Each screen is scrolled with A11yScrollAudit and Apple's findings
//  are compared with that answer key:
//
//      expected FAIL, flagged      true positive
//      expected FAIL, not flagged  false negative  (a defect Apple missed)
//      expected PASS, flagged      false positive  (a false alarm)
//      expected PASS, not flagged  true negative
//
//  Disabled controls (WCAG-exempt) and text over gradients (no single correct
//  ratio) are reported separately and never counted as errors. Element
//  detection looks for controls that are NOT in the accessibility tree, so it
//  is graded per screen by count instead of per element.
//
//  The tests measure; they do not fail on mismatches. They fail only when the
//  scroll did not reach, or the audit never completed for, an element they
//  need to grade, because then the numbers would be wrong.
//
//  The answer key is in Shared/RuleGroundTruth.swift. It comes from the
//  accessibility guidelines, not from Apple's output, so review it.
//

import XCTest
import A11yScrollAudit

@MainActor
final class ProductionScreenAccuracyTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Apple's contrast audit reports two severities: "Contrast failed" and
    /// "Contrast nearly passed". Measured on this app, "nearly passed" appears
    /// only on text that is really below WCAG AA (ratios between roughly 3.3 and
    /// 4.5 for normal text), never on text that passes, so it is a genuine
    /// detection at lower severity and counts as flagged. Set to false to count
    /// only "failed" and see how much that hides.
    private static let countNearlyPassedAsFlag = true

    /// Print each page's on-screen items and issue counts. Turned on while
    /// diagnosing the unreached DASH-F1 elements; set to false afterwards (or
    /// use the AUDIT_VERBOSE=1 environment variable instead).
    private static let verboseByDefault = true

    // MARK: - Choose the rules

    /// Whatever AUDIT_RULES says; all rules when it is unset or unrecognised.
    func testAccuracy_selectedRules() throws { try runAndReport(rules: Self.rulesFromEnvironment()) }

    func testAccuracy_allRules() throws { try runAndReport(rules: AuditRule.allCases) }

    func testAccuracy_contrast() throws { try runAndReport(rules: [.contrast]) }
    func testAccuracy_hitRegion() throws { try runAndReport(rules: [.hitRegion]) }
    func testAccuracy_elementDescription() throws { try runAndReport(rules: [.sufficientElementDescription]) }
    func testAccuracy_dynamicType() throws { try runAndReport(rules: [.dynamicType]) }
    func testAccuracy_textClipped() throws { try runAndReport(rules: [.textClipped]) }
    func testAccuracy_trait() throws { try runAndReport(rules: [.trait]) }
    func testAccuracy_elementDetection() throws { try runAndReport(rules: [.elementDetection]) }

    private static func rulesFromEnvironment() -> [AuditRule] {
        guard let raw = ProcessInfo.processInfo.environment["AUDIT_RULES"], !raw.isEmpty else {
            return AuditRule.allCases
        }
        let rules = AuditRule.parse(raw)
        return rules.isEmpty ? AuditRule.allCases : rules
    }

    // MARK: - Grading model

    private struct Verdict {
        enum Kind { case truePositive, falseNegative, falsePositive, trueNegative }
        let expectation: Expectation
        let kind: Kind
        let warned: Bool          // Apple said "nearly passed" (borderline), not "failed"
        /// A missed defect (FN) that sits inside the narrowed candidates of a
        /// finding Apple raised but could not pin to one element. The defect may
        /// well have been caught: the limit is localising it, not Apple.
        var ambiguous = false
    }

    private struct FlagNote {
        let expectation: Expectation
        let flagged: Bool
    }

    private struct ScreenLevel {
        let rule: AuditRule
        let expected: Int
        let reported: Int
    }

    private struct ScreenGrade {
        let screen: String
        var verdicts: [Verdict] = []
        var exempt: [FlagNote] = []
        var unmeasurable: [FlagNote] = []
        var screenLevel: [ScreenLevel] = []
        var unexpected: [String] = []        // findings with no expectation for that rule
        var unlocalised: [String] = []       // findings Apple could not tie to one element
        var missing: [Expectation] = []      // elements the scroll or audit did not cover
        var notes: [String] = []             // diagnostics, printed under the screen
        var pages = 0
        var edgeArtifacts = 0
        var incompleteAudits: [String] = []
    }

    private struct Counts {
        var tp = 0, fn = 0, fp = 0, tn = 0
        /// Of `fn`, how many sit in the candidates of an unlocalised finding.
        var fnAmbiguous = 0
        /// Of `tp`, how many were reported only as "nearly passed", not "failed".
        var tpSoft = 0
        var total: Int { tp + fn + fp + tn }

        mutating func add(_ kind: Verdict.Kind, ambiguous: Bool = false, softOnly: Bool = false) {
            switch kind {
            case .truePositive:
                tp += 1
                if softOnly { tpSoft += 1 }
            case .falseNegative:
                fn += 1
                if ambiguous { fnAmbiguous += 1 }
            case .falsePositive: fp += 1
            case .trueNegative: tn += 1
            }
        }

        func summary(_ label: String) -> String {
            func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "n/a" : String(format: "%.0f%%", Double(a) / Double(b) * 100) }
            var text = "\(label): accuracy \(pct(tp + tn, total)) (\(tp + tn)/\(total)), "
                + "caught \(tp)/\(tp + fn) real defects (recall \(pct(tp, tp + fn))), "
                + "\(fp) false alarm(s) (precision \(pct(tp, tp + fp)))"
            if tpSoft > 0 {
                text += "; of the \(tp) caught, \(tp - tpSoft) as 'failed' and \(tpSoft) as 'nearly passed'"
            }
            if fnAmbiguous > 0 {
                text += "; \(fnAmbiguous) of the \(fn) misses sit inside unlocalised findings, "
                    + "so recall is between \(pct(tp, tp + fn)) and \(pct(tp + fnAmbiguous, tp + fn))"
            }
            return text
        }
    }

    // MARK: - Run

    private func runAndReport(rules: [AuditRule]) throws {
        let screens = GroundTruth.screens(covering: rules)
        var grades: [ScreenGrade] = []
        for screen in screens {
            grades.append(try gradeScreen(screen, rules: rules))
        }

        let text = render(grades, rules: rules)
        print(text)

        let attachment = XCTAttachment(string: text)
        attachment.name = "Apple audit accuracy: \(rules.map(\.rawValue).joined(separator: ", "))"
        attachment.lifetime = .keepAlways
        add(attachment)

        for grade in grades {
            XCTAssertTrue(grade.missing.isEmpty,
                          "\(grade.screen): not reached or not audited: \(grade.missing.map { "\($0.rule.rawValue):\($0.id)" })")
        }
    }

    private func gradeScreen(_ screen: String, rules: [AuditRule]) throws -> ScreenGrade {
        let allExpectations = GroundTruth.expectations(for: screen)
        let graded = allExpectations.filter { rules.contains($0.rule) }

        let app = XCUIApplication()
        app.launchEnvironment["AUDIT_SCREEN"] = screen
        app.launch()

        if let first = graded.first(where: { $0.rule.gradesPerElement }) {
            let element = app.descendants(matching: .any)[first.id]
            XCTAssertTrue(element.waitForExistence(timeout: 10), "\(screen): screen did not open")
        }

        var options = A11yScrollAudit.Options(
            auditTypes: A11yScrollAudit.auditTypes(named: rules.map { $0.rawValue }))
        options.stepFraction = 0.3
        options.maxPages = 30
        options.attachScreenshots = false
        // AUDIT_VERBOSE=1 prints every page's items and issue counts, for
        // diagnosing elements the scroll did not reach.
        options.verbose = Self.verboseByDefault || ProcessInfo.processInfo.environment["AUDIT_VERBOSE"] == "1"
        let report = try A11yScrollAudit.run(app: app, name: screen, options: options)

        // Apple names an element by identifier, or by label for controls that
        // carry the identifier on a child.
        var idToText: [String: String] = [:]
        for spec in GroundTruth.specs(for: screen) { idToText[spec.id] = spec.text }
        for control in RuleGroundTruth.controls(for: screen) { idToText[control.id] = control.text }
        let knownIDs = Set(idToText.keys)
        let uniqueTextToID: [String: String] = Dictionary(grouping: idToText.keys, by: { idToText[$0] ?? "" })
            .filter { $0.value.count == 1 }
            .mapValues { $0[0] }
        func resolve(_ name: String?) -> String? {
            guard let name else { return nil }
            return knownIDs.contains(name) ? name : uniqueTextToID[name]
        }
        let expectationKeys = Set(allExpectations.map { "\($0.rule.rawValue)|\($0.id)" })

        var grade = ScreenGrade(screen: screen)
        grade.pages = report.pagesAudited
        grade.edgeArtifacts = report.edgeArtifacts.count
        grade.incompleteAudits = report.incompleteAudits

        var flagged: [AuditRule: Set<String>] = [:]
        var warned: [AuditRule: Set<String>] = [:]
        var hard: [AuditRule: Set<String>] = [:]        // reported as "failed" (contrast)
        var ambiguous: [AuditRule: Set<String>] = [:]   // candidates of unlocalised findings
        var screenLevelCount: [AuditRule: Int] = [:]

        for finding in report.findings {
            guard let rule = AuditRule(rawValue: finding.type) else {
                grade.unexpected.append("\(finding.type): \(finding.summary)")
                continue
            }
            if !rule.gradesPerElement {
                screenLevelCount[rule, default: 0] += 1
                continue
            }
            let isWarning = rule == .contrast && finding.summary.localizedCaseInsensitiveContains("nearly passed")

            var target: String?
            if let element = finding.element {
                target = resolve(element)
                if target == nil {
                    grade.unexpected.append("\(rule.rawValue) on \(element) (outside the ground truth): \(finding.summary)")
                    continue
                }
            } else {
                let candidates = finding.candidates.compactMap { resolve($0) }
                if candidates.count == 1 {
                    target = candidates[0]
                } else {
                    if candidates.count > 1 { ambiguous[rule, default: []].formUnion(candidates) }
                    grade.unlocalised.append("\(rule.rawValue): \(finding.summary), candidates \(candidates.isEmpty ? finding.candidates : candidates)")
                    continue
                }
            }
            guard let elementID = target else { continue }
            if !expectationKeys.contains("\(rule.rawValue)|\(elementID)") {
                grade.unexpected.append("\(rule.rawValue) on \(elementID) (no expectation for this rule): \(finding.summary)")
                continue
            }
            if isWarning {
                warned[rule, default: []].insert(elementID)
                if Self.countNearlyPassedAsFlag { flagged[rule, default: []].insert(elementID) }
            } else {
                hard[rule, default: []].insert(elementID)
                flagged[rule, default: []].insert(elementID)
            }
        }

        let covered = Set(report.itemsCovered)
        let unaudited = Set(report.unauditedItems)
        for expectation in graded {
            if !expectation.rule.gradesPerElement { continue }

            let text = idToText[expectation.id] ?? ""
            let reached = covered.contains(expectation.id) || covered.contains(text)
            if !reached || unaudited.contains(expectation.id) || unaudited.contains(text) {
                grade.missing.append(expectation)
                continue
            }

            let isFlagged = flagged[expectation.rule]?.contains(expectation.id) ?? false
            // Flagged ONLY as "nearly passed", never as "failed".
            let isWarned = (warned[expectation.rule]?.contains(expectation.id) ?? false)
                && !(hard[expectation.rule]?.contains(expectation.id) ?? false)
            switch expectation.outcome {
            case .fail:
                let inCandidates = !isFlagged && (ambiguous[expectation.rule]?.contains(expectation.id) ?? false)
                grade.verdicts.append(Verdict(expectation: expectation,
                                              kind: isFlagged ? .truePositive : .falseNegative,
                                              warned: isWarned,
                                              ambiguous: inCandidates))
            case .pass:
                grade.verdicts.append(Verdict(expectation: expectation, kind: isFlagged ? .falsePositive : .trueNegative, warned: isWarned))
            case .exempt:
                grade.exempt.append(FlagNote(expectation: expectation, flagged: isFlagged))
            case .unmeasurable:
                grade.unmeasurable.append(FlagNote(expectation: expectation, flagged: isFlagged || isWarned))
            }
        }

        // When elements were not reached, show what WAS seen that the answer key
        // does not recognise. If the missing elements were exposed under another
        // name (merged into one element, say), it shows up here.
        if !grade.missing.isEmpty {
            let unrecognised = covered
                .filter { !knownIDs.contains($0) && uniqueTextToID[$0] == nil }
                .sorted()
            grade.notes.append("elements seen but not in the answer key (\(unrecognised.count)): \(unrecognised)")
            let wanted = grade.missing.map { $0.id }
            grade.notes.append("not reached: \(wanted)")
            let neighbours = covered.filter { $0.hasPrefix("DASH-F") || $0.hasPrefix("DASH-A") || $0.hasPrefix("DASH-TRAIT") }
                .sorted { $0.compare($1, options: .numeric) == .orderedAscending }
            if screen == "dashboard" { grade.notes.append("covered feed/alert/link elements: \(neighbours)") }
            grade.notes.append("pages: \(report.pagesAudited), items covered in total: \(covered.count)")
        }

        // Rules whose problem element is not in the accessibility tree: graded
        // per screen, by how many such controls exist versus how many were reported.
        for rule in rules where !rule.gradesPerElement {
            let expected = graded.filter { $0.rule == rule && $0.outcome == .fail }.count
            if expected > 0 || (screenLevelCount[rule] ?? 0) > 0 {
                grade.screenLevel.append(ScreenLevel(rule: rule, expected: expected, reported: screenLevelCount[rule] ?? 0))
            }
        }
        return grade
    }

    // MARK: - Report

    private func render(_ grades: [ScreenGrade], rules: [AuditRule]) -> String {
        var lines = ["=== APPLE ACCESSIBILITY AUDIT: ACCURACY BY RULE ===",
                     "rules run: \(rules.map { $0.rawValue }.joined(separator: ", "))"]

        for grade in grades {
            lines.append("")
            lines.append("--- \(grade.screen): \(grade.pages) page(s), \(grade.edgeArtifacts) edge artifact(s) discarded"
                         + (grade.incompleteAudits.isEmpty ? "" : ", audits not completed: \(grade.incompleteAudits)"))

            let ordered = grade.verdicts.sorted {
                if $0.expectation.rule != $1.expectation.rule {
                    return $0.expectation.rule.rawValue < $1.expectation.rule.rawValue
                }
                return $0.expectation.id.compare($1.expectation.id, options: .numeric) == .orderedAscending
            }
            for verdict in ordered {
                let tag: String
                switch verdict.kind {
                case .truePositive: tag = "TP"
                case .falseNegative: tag = verdict.ambiguous ? "FN?" : "FN"
                case .falsePositive: tag = "FP"
                case .trueNegative: tag = "TN"
                }
                let should = verdict.expectation.outcome == .fail ? "should flag" : "should pass"
                lines.append("  \(tag)  [\(verdict.expectation.rule.rawValue)] \(verdict.expectation.id): "
                             + "\(verdict.expectation.detail), \(should)" + (verdict.warned ? "  [Apple: nearly passed]" : ""))
            }
            for note in grade.exempt {
                lines.append("  --  [\(note.expectation.rule.rawValue)] \(note.expectation.id): disabled, "
                             + "\(note.expectation.detail): Apple \(note.flagged ? "FLAGGED it (exempt under WCAG)" : "left it alone")")
            }
            for note in grade.unmeasurable {
                lines.append("  ??  [\(note.expectation.rule.rawValue)] \(note.expectation.id): over a gradient: "
                             + "Apple \(note.flagged ? "flagged it" : "left it alone") (no correct answer)")
            }
            for level in grade.screenLevel {
                lines.append("  ##  [\(level.rule.rawValue)] screen-level: \(level.expected) hidden control(s) built in, "
                             + "Apple reported \(level.reported) (graded by count, not by element)")
            }
            for item in grade.missing { lines.append("  !!  [\(item.rule.rawValue)] \(item.id): NOT REACHED or not audited, not graded") }
            for item in grade.notes { lines.append("  ..  \(item)") }
            for item in grade.unexpected { lines.append("  ..  \(item)") }
            for item in grade.unlocalised { lines.append("  ..  not localised: \(item)") }
        }

        lines.append("")
        lines.append("=== BY RULE (all screens) ===")
        var overall = Counts()
        for rule in rules {
            var counts = Counts()
            for grade in grades {
                for verdict in grade.verdicts where verdict.expectation.rule == rule {
                    counts.add(verdict.kind, ambiguous: verdict.ambiguous, softOnly: verdict.warned)
                }
                for level in grade.screenLevel where level.rule == rule {
                    counts.tp += min(level.expected, level.reported)
                    counts.fn += max(level.expected - level.reported, 0)
                    counts.fp += max(level.reported - level.expected, 0)
                }
            }
            overall.tp += counts.tp; overall.fn += counts.fn; overall.fp += counts.fp; overall.tn += counts.tn
            overall.fnAmbiguous += counts.fnAmbiguous
            overall.tpSoft += counts.tpSoft
            lines.append("  " + (counts.total == 0 ? "\(rule.rawValue): nothing graded" : counts.summary(rule.rawValue)))
        }
        if rules.count > 1 { lines.append("  " + overall.summary("ALL RULES")) }

        let exempt = grades.flatMap { $0.exempt }
        if !exempt.isEmpty {
            lines.append("disabled controls flagged by Apple: \(exempt.filter { $0.flagged }.count) of \(exempt.count)")
        }
        return lines.joined(separator: "\n")
    }
}
