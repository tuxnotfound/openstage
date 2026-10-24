// The value axis of a chart of counts: about three steps of 1, 2, 2.5 (from
// 25 up), 5 or 10 times a power of ten, as ProgressChart::Scale draws it.
export function ticks(max: number): number[] {
  const raw = max / 3
  const power = 10 ** Math.floor(Math.log10(raw))
  const step = stepFor(raw / power, power) * power
  const count = Math.ceil(max / step - 1e-9)
  return Array.from({ length: count + 1 }, (_, k) => whole(k * step))
}

function stepFor(mantissa: number, power: number): number {
  if (mantissa <= 1) return 1
  if (mantissa <= 2) return 2
  if (mantissa <= 2.5 && power >= 10) return 2.5
  if (mantissa <= 5) return 5
  return 10
}

function whole(value: number): number {
  const tenth = Math.round(value * 10) / 10
  return tenth === Math.round(value) ? Math.round(value) : tenth
}
