// c / f / k conversion via Celsius (spec 5.3). Reject any input below
// absolute zero with BELOW_ABSOLUTE_ZERO.
import { fail } from '../shared/index.js';

const ABS_ZERO = { c: -273.15, f: -459.67, k: 0 };
const toCelsius = { c: (v) => v, f: (v) => ((v - 32) * 5) / 9, k: (v) => v - 273.15 };
const fromCelsius = { c: (v) => v, f: (v) => (v * 9) / 5 + 32, k: (v) => v + 273.15 };

export function checkTemperature(value, unit) {
  if (value < ABS_ZERO[unit]) fail('BELOW_ABSOLUTE_ZERO', 'Temperature is below absolute zero');
}

export function convertTemperature(value, from, to) {
  checkTemperature(value, from);
  if (from === to) return value;
  const result = fromCelsius[to](toCelsius[from](value));
  // Valid input can never land below absolute zero; clamp float noise at the edge.
  return Math.max(result, ABS_ZERO[to]);
}
