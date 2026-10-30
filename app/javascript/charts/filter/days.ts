// The window's calendar in days and months as the server writes them,
// "2026-10-03" and "2026-10", in the builder's calendar: the server says
// which day is today there, so the visitor's own zone has no say. Weeks
// start on Monday, as the chart's ISO weeks do. The days picked travel in
// the range param as "2026-10-03..2026-10-28" (Progress::Days).

export type Day = string
export type Month = string
export type Picked = { from: Day; to: Day }

const DAY = /^(\d{4})-(\d{2})-(\d{2})$/
const PICKED = /^(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})$/
const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
// The calendar offers no day before this, as the server takes none.
export const EARLIEST: Day = "2008-01-01"

function date(day: Day): Date {
  const [, year = "0", month = "1", number = "1"] = DAY.exec(day) ?? []
  return new Date(Date.UTC(Number(year), Number(month) - 1, Number(number)))
}

function dayOf(value: Date): Day {
  return value.toISOString().slice(0, 10)
}

export function addDays(day: Day, count: number): Day {
  const value = date(day)
  value.setUTCDate(value.getUTCDate() + count)
  return dayOf(value)
}

export function monthOf(day: Day): Month {
  return day.slice(0, 7)
}

export function addMonths(month: Month, count: number): Month {
  return monthOf(dayOf(new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)) - 1 + count, 1))))
}

// The same day of another month, or that month's last when it is shorter.
export function sameDayIn(day: Day, count: number): Day {
  const month = addMonths(monthOf(day), count)
  const same = `${month}-${day.slice(8)}`
  return valid(same) ? same : lastOf(month)
}

function valid(day: Day): boolean {
  return dayOf(date(day)) === day
}

export function lastOf(month: Month): Day {
  return addDays(`${addMonths(month, 1)}-01`, -1)
}

// 0 for Monday to 6 for Sunday.
export function weekday(day: Day): number {
  return (date(day).getUTCDay() + 6) % 7
}

// A month's weeks, Monday first, null where a day belongs to the month
// before or after.
export function weeksOf(month: Month): (Day | null)[][] {
  const first = `${month}-01`
  const cells: (Day | null)[] = Array.from({ length: weekday(first) }, () => null)
  for (let day = first; monthOf(day) === month; day = addDays(day, 1)) cells.push(day)
  while (cells.length % 7 !== 0) cells.push(null)
  return Array.from({ length: cells.length / 7 }, (_, week) => cells.slice(week * 7, week * 7 + 7))
}

export function ordered(one: Day, other: Day): Picked {
  return one <= other ? { from: one, to: other } : { from: other, to: one }
}

export function within(day: Day, span: Picked | null): boolean {
  return span !== null && day >= span.from && day <= span.to
}

export function clamp(day: Day, min: Day, max: Day): Day {
  return day < min ? min : day > max ? max : day
}

// Where a key moves the calendar's focus, as the WAI-ARIA date picker
// dialog moves it: a day with the arrows, the week's Monday or Sunday with
// Home and End, a month with Page Up and Page Down, a year with Shift. null
// for any other key.
export function moved(day: Day, key: string, shift = false): Day | null {
  switch (key) {
    case "ArrowLeft": return addDays(day, -1)
    case "ArrowRight": return addDays(day, 1)
    case "ArrowUp": return addDays(day, -7)
    case "ArrowDown": return addDays(day, 7)
    case "Home": return addDays(day, -weekday(day))
    case "End": return addDays(day, 6 - weekday(day))
    case "PageUp": return sameDayIn(day, shift ? -12 : -1)
    case "PageDown": return sameDayIn(day, shift ? 12 : 1)
    default: return null
  }
}

// The months the calendar opens on, oldest first: the last ends the days
// picked, else holds today, and with two the month before sits on its left.
export function openingMonths(picked: Picked | null, today: Day, count: number): Month[] {
  const last = monthOf(picked ? picked.to : today)
  return Array.from({ length: count }, (_, i) => addMonths(last, i - count + 1))
}

// The months on show once focus moves to a day: as they were while it is
// among them, else moved just far enough to hold it.
export function monthsHolding(months: Month[], day: Day): Month[] {
  const first = months[0]
  const last = months[months.length - 1]
  if (!first || !last) return [monthOf(day)]
  const month = monthOf(day)
  if (month < first) return months.map((_, i) => addMonths(month, i))
  if (month > last) return months.map((_, i) => addMonths(month, i - months.length + 1))
  return months
}

// The range param for some days, and the days a range param names.
export function rangeParam(span: Picked): `${Day}..${Day}` {
  return `${span.from}..${span.to}`
}

export function pickedIn(range: string): Picked | null {
  const match = PICKED.exec(range)
  return match?.[1] && match[2] ? ordered(match[1], match[2]) : null
}

// "Saturday, 3 October 2026", for a screen reader.
export function dayLabel(day: Day): string {
  const value = date(day)
  return `${WEEKDAYS[weekday(day)]}, ${value.getUTCDate()} ${MONTHS[value.getUTCMonth()]} ${value.getUTCFullYear()}`
}

// "October 2026".
export function monthLabel(month: Month): string {
  return `${MONTHS[Number(month.slice(5, 7)) - 1]} ${month.slice(0, 4)}`
}

// "3 Oct", as the window names its days.
export function shortDay(day: Day): string {
  const value = date(day)
  return `${value.getUTCDate()} ${MONTHS[value.getUTCMonth()]?.slice(0, 3)}`
}

export const WEEKDAY_NAMES = WEEKDAYS
