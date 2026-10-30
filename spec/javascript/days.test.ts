import { describe, expect, test } from "vitest"
import {
  addDays, addMonths, clamp, dayLabel, lastOf, monthLabel, monthsHolding, moved, openingMonths, ordered, pickedIn, rangeParam, sameDayIn, shortDay,
  weekday, weeksOf, within,
} from "../../app/javascript/charts/filter/days"

describe("the calendar's days", () => {
  test("count across months and years, and across a leap day", () => {
    expect(addDays("2026-10-31", 1)).toBe("2026-11-01")
    expect(addDays("2027-01-01", -1)).toBe("2026-12-31")
    expect(addDays("2028-02-28", 1)).toBe("2028-02-29")
    expect(addMonths("2026-12", 1)).toBe("2027-01")
    expect(addMonths("2026-01", -13)).toBe("2024-12")
    expect(lastOf("2026-02")).toBe("2026-02-28")
  })

  test("start the week on Monday, as ISO weeks do", () => {
    expect(weekday("2026-10-26")).toBe(0)
    expect(weekday("2026-11-01")).toBe(6)
    const weeks = weeksOf("2026-10")
    expect(weeks[0]).toEqual([null, null, null, "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"])
    expect(weeks[weeks.length - 1]).toEqual(["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", null])
    expect(weeksOf("2026-02").flat().filter(Boolean)).toHaveLength(28)
  })

  test("are picked in either order, one day on its own too", () => {
    expect(ordered("2026-10-28", "2026-10-03")).toEqual({ from: "2026-10-03", to: "2026-10-28" })
    expect(ordered("2026-10-03", "2026-10-03")).toEqual({ from: "2026-10-03", to: "2026-10-03" })
    expect([within("2026-10-03", { from: "2026-10-03", to: "2026-10-28" }), within("2026-10-29", { from: "2026-10-03", to: "2026-10-28" }), within("2026-10-03", null)])
      .toEqual([true, false, false])
  })

  test("travel in the range param, and come back from it in order", () => {
    expect(rangeParam({ from: "2026-10-03", to: "2026-10-28" })).toBe("2026-10-03..2026-10-28")
    expect(pickedIn("2026-10-28..2026-10-03")).toEqual({ from: "2026-10-03", to: "2026-10-28" })
    expect([pickedIn("30d"), pickedIn("2026-10-03"), pickedIn("2026-10-03...2026-10-28")]).toEqual([null, null, null])
  })

  test("keep inside the days the calendar offers", () => {
    expect([clamp("2026-11-02", "2026-06-02", "2026-10-30"), clamp("2026-01-01", "2026-06-02", "2026-10-30"), clamp("2026-07-01", "2026-06-02", "2026-10-30")])
      .toEqual(["2026-10-30", "2026-06-02", "2026-07-01"])
  })

  test("go by name for a screen reader, and by the window's short name", () => {
    expect(dayLabel("2026-10-03")).toBe("Saturday, 3 October 2026")
    expect(monthLabel("2026-10")).toBe("October 2026")
    expect(shortDay("2026-10-03")).toBe("3 Oct")
  })
})

describe("the keyboard", () => {
  test("moves a day with the arrows, a week up and down, to the week's Monday and Sunday with Home and End", () => {
    expect(["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].map((key) => moved("2026-10-01", key)))
      .toEqual(["2026-09-30", "2026-10-02", "2026-09-24", "2026-10-08", "2026-09-28", "2026-10-04"])
  })

  test("moves a month with Page Up and Page Down, a year with Shift, to the month's last day when it is shorter", () => {
    expect([moved("2026-03-31", "PageUp"), moved("2026-01-31", "PageDown"), moved("2028-02-29", "PageDown", true), moved("2026-10-15", "PageUp", true)])
      .toEqual(["2026-02-28", "2026-02-28", "2029-02-28", "2025-10-15"])
    expect(sameDayIn("2026-08-31", 1)).toBe("2026-09-30")
  })

  test("leaves every other key alone", () => {
    expect([moved("2026-10-01", "Enter"), moved("2026-10-01", " "), moved("2026-10-01", "a")]).toEqual([null, null, null])
  })
})

describe("the months on show", () => {
  test("open on today's month with the month before it on its left, or on the month the days picked end in", () => {
    expect(openingMonths(null, "2026-10-30", 2)).toEqual(["2026-09", "2026-10"])
    expect(openingMonths(null, "2026-01-05", 2)).toEqual(["2025-12", "2026-01"])
    expect(openingMonths({ from: "2026-08-20", to: "2026-09-04" }, "2026-10-30", 2)).toEqual(["2026-08", "2026-09"])
    expect(openingMonths({ from: "2026-08-20", to: "2026-09-04" }, "2026-10-30", 1)).toEqual(["2026-09"])
  })

  test("stay while the day in focus is among them, else move just far enough to hold it", () => {
    expect(monthsHolding(["2026-09", "2026-10"], "2026-09-30")).toEqual(["2026-09", "2026-10"])
    expect(monthsHolding(["2026-09", "2026-10"], "2026-11-02")).toEqual(["2026-10", "2026-11"])
    expect(monthsHolding(["2026-09", "2026-10"], "2026-08-31")).toEqual(["2026-08", "2026-09"])
    expect(monthsHolding(["2026-10"], "2027-10-01")).toEqual(["2027-10"])
  })
})
