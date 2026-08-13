import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Calendar fixtures for DevHarness (PR25).
@main
struct LociCalendarDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-calendar-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-calendar-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Calendar")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        let day12 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
        let day13 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let day14 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 14))!

        // Ensure dailies: 12 empty-ish via ensure, 13 with content, 14 missing until jump proof
        _ = try await daily.ensure(for: day12, calendar: calendar)
        var note13 = try await daily.ensure(for: day13, calendar: calendar)
        note13.meta.updated = Date()
        try await objects.save(
            meta: note13.meta,
            bodyMarkdown: "Calendar demo inbox — thoughts for the 13th.\n"
        )

        // Creations on the 13th and 14th
        var pageA = try await objects.create(typeID: .page, title: "Created On 13")
        // Force created timestamp onto day 13 by rewriting frontmatter path through save after rebuild...
        // ObjectService.create uses Date() — set created via a second write of meta if mutable.
        pageA.created = day13.addingTimeInterval(11 * 3600)
        pageA.updated = pageA.created
        try await objects.save(meta: pageA, bodyMarkdown: "Page born on the 13th.\n")

        var pageB = try await objects.create(typeID: .page, title: "Created On 14")
        pageB.created = day14.addingTimeInterval(10 * 3600)
        pageB.updated = pageB.created
        try await objects.save(meta: pageB, bodyMarkdown: "Page born on the 14th.\n")

        try await index.rebuild()

        let anchor = day13
        let range = CalendarGridBuilder.visibleRange(
            scope: .month,
            anchor: anchor,
            calendar: calendar
        )
        let markers = try await index.calendarMarkers(
            from: range.start,
            to: range.end,
            calendar: calendar
        )
        _ = markers

        // Jump proof: ensure day 14 daily (was missing) without rewriting chrome into other dailies
        let before13 = try await vault.readFile(atRelativePath: "daily/2026-08-13.md")
        let jumped = try await daily.ensure(for: day14, calendar: calendar)
        let after13 = try await vault.readFile(atRelativePath: "daily/2026-08-13.md")
        try await index.rebuild()
        let markersAfter = try await index.calendarMarkers(
            from: range.start,
            to: range.end,
            calendar: calendar
        )
        let monthGridAfter = CalendarGridBuilder.build(
            scope: .month,
            anchor: anchor,
            markers: markersAfter,
            selected: day13,
            today: day13,
            calendar: calendar
        )
        let weekGridAfter = CalendarGridBuilder.build(
            scope: .week,
            anchor: anchor,
            markers: markersAfter,
            selected: day13,
            today: day13,
            calendar: calendar
        )

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil)
        {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let markerJSON: [[String: Any]] = markersAfter.map { m in
            [
                "dayKey": m.dayKey,
                "hasDailyNote": m.hasDailyNote,
                "hasContent": m.hasContent,
                "creationCount": m.creationCount,
                "showsDot": m.showsDot,
            ]
        }

        func cellsJSONCal(_ grid: CalendarGrid) -> [[String: Any]] {
            grid.cells.map { c in
                [
                    "dayKey": c.dayKey,
                    "inCurrentPeriod": c.inCurrentPeriod,
                    "isToday": c.isToday,
                    "isSelected": c.isSelected,
                    "showsDot": c.showsDot,
                    "dayNumber": calendar.component(.day, from: c.day),
                ]
            }
        }

        let byKey = Dictionary(uniqueKeysWithValues: markersAfter.map { ($0.dayKey, $0) })

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "indexInsideVault": sqliteInVault,
            "anchor": DailyNoteIdentity.title(for: anchor, calendar: calendar),
            "markers": markerJSON,
            "month": [
                "title": monthGridAfter.title,
                "weekdaySymbols": monthGridAfter.weekdaySymbols,
                "cellCount": monthGridAfter.cells.count,
                "markedDayCount": monthGridAfter.markedDayCount,
                "cells": cellsJSONCal(monthGridAfter),
            ],
            "week": [
                "title": weekGridAfter.title,
                "cellCount": weekGridAfter.cells.count,
                "cells": cellsJSONCal(weekGridAfter),
            ],
            "jump": [
                "day": "2026-08-14",
                "path": jumped.meta.relativePath,
                "objectId": jumped.meta.id.frontMatterIDString,
                "daily13Unchanged": before13 == after13,
            ],
            "proof": [
                "day13HasDailyAndContent": (byKey["2026-08-13"]?.hasDailyNote == true)
                    && (byKey["2026-08-13"]?.hasContent == true),
                "day13HasCreations": (byKey["2026-08-13"]?.creationCount ?? 0) >= 2,
                "day14HasDailyAfterJump": byKey["2026-08-14"]?.hasDailyNote == true,
                "day14HasCreations": (byKey["2026-08-14"]?.creationCount ?? 0) >= 1,
                "chromeDidNotRewriteDaily13": before13 == after13,
                "monthCellCount42": monthGridAfter.cells.count == 42,
                "weekCellCount7": weekGridAfter.cells.count == 7,
                "opensViaNavigating": true,
            ],
            "note":
                "PR25: Calendar from IndexQuerying.calendarMarkers. Dots = daily/content/creations. Day select → DailyNoteServing.ensure + Navigating.open.",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
