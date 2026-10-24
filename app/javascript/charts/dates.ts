// Calendar days as "YYYY-MM-DD" strings, the server's dates in the builder's
// zone. All arithmetic runs in UTC, so no local zone shifts a day.

export type Day = string

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const LONG_MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

export function parse(day: Day): Date {
  return new Date(`${day}T00:00:00Z`)
}

export function format(date: Date): Day {
  return date.toISOString().slice(0, 10)
}

export function addDays(day: Day, count: number): Day {
  const date = parse(day)
  date.setUTCDate(date.getUTCDate() + count)
  return format(date)
}

// Like Ruby's Date#<<: the same day n months back, or the month's last day.
export function addMonths(day: Day, count: number): Day {
  const date = parse(day)
  const target = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + count, 1))
  const last = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate()
  target.setUTCDate(Math.min(date.getUTCDate(), last))
  return format(target)
}

export function monthStart(day: Day): Day {
  return `${day.slice(0, 7)}-01`
}

export function monthEnd(day: Day): Day {
  return addDays(addMonths(monthStart(day), 1), -1)
}

// 1 for Monday, 7 for Sunday, as Ruby's cwday.
export function cwday(day: Day): number {
  return parse(day).getUTCDay() || 7
}

export function daysBetween(from: Day, to: Day): number {
  return Math.round((parse(to).getTime() - parse(from).getTime()) / 86_400_000)
}

export function each(from: Day, to: Day): Day[] {
  const days: Day[] = []
  for (let day = from; day <= to; day = addDays(day, 1)) days.push(day)
  return days
}

export function min(a: Day, b: Day): Day {
  return a < b ? a : b
}

export const year = (day: Day): number => Number(day.slice(0, 4))
export const month = (day: Day): number => Number(day.slice(5, 7))
export const dayOfMonth = (day: Day): number => Number(day.slice(8, 10))

// "Oct 3"
export function short(day: Day): string {
  return `${MONTHS[month(day) - 1]} ${dayOfMonth(day)}`
}

// "Oct", "Oct 2025", "October 2026", "Fri, Oct 3", "March 26".
export const monthName = (day: Day): string => MONTHS[month(day) - 1] ?? ""
export const longMonth = (day: Day): string => LONG_MONTHS[month(day) - 1] ?? ""
export const weekday = (day: Day): string => WEEKDAYS[parse(day).getUTCDay()] ?? ""
