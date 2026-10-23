"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.istShifted = istShifted;
exports.istDateKey = istDateKey;
exports.istHour = istHour;
exports.istDayStartUtc = istDayStartUtc;
exports.istDayEndUtc = istDayEndUtc;
exports.istHourUtc = istHourUtc;
exports.indianFinancialYear = indianFinancialYear;
exports.settlementScheduledFor = settlementScheduledFor;
exports.hoursBetween = hoursBetween;
exports.addMinutes = addMinutes;
exports.addDays = addDays;
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
function istShifted(d) {
    return new Date(d.getTime() + IST_OFFSET_MS);
}
function istDateKey(d) {
    const s = istShifted(d);
    return `${s.getUTCFullYear()}${String(s.getUTCMonth() + 1).padStart(2, '0')}${String(s.getUTCDate()).padStart(2, '0')}`;
}
function istHour(d) {
    return istShifted(d).getUTCHours();
}
function istDayStartUtc(d) {
    const s = istShifted(d);
    return new Date(Date.UTC(s.getUTCFullYear(), s.getUTCMonth(), s.getUTCDate()) - IST_OFFSET_MS);
}
function istDayEndUtc(d) {
    return new Date(istDayStartUtc(d).getTime() + 24 * 60 * 60 * 1000 - 1);
}
function istHourUtc(dateKey, hour) {
    const y = Number(dateKey.slice(0, 4));
    const m = Number(dateKey.slice(4, 6)) - 1;
    const day = Number(dateKey.slice(6, 8));
    return new Date(Date.UTC(y, m, day, hour, 0, 0) - IST_OFFSET_MS);
}
/** Indian financial year (1 April – 31 March) in IST. */
function indianFinancialYear(d) {
    const s = istShifted(d);
    const year = s.getUTCFullYear();
    const fyStartYear = s.getUTCMonth() >= 3 ? year : year - 1;
    const startUtc = new Date(Date.UTC(fyStartYear, 3, 1) - IST_OFFSET_MS);
    const endUtc = new Date(Date.UTC(fyStartYear + 1, 2, 31, 23, 59, 59) - IST_OFFSET_MS);
    return { key: `${fyStartYear}-${String((fyStartYear + 1) % 100).padStart(2, '0')}`, start: startUtc, end: endUtc };
}
/** Settlement is scheduled for 11:00 IST on the day after the event's last day (PRD §8.3). */
function settlementScheduledFor(eventEndAt) {
    const nextDay = new Date(istDayStartUtc(eventEndAt).getTime() + 24 * 60 * 60 * 1000);
    const nextDayKey = istDateKey(nextDay);
    return istHourUtc(nextDayKey, 11);
}
function hoursBetween(from, to) {
    return (to.getTime() - from.getTime()) / (60 * 60 * 1000);
}
function addMinutes(d, minutes) {
    return new Date(d.getTime() + minutes * 60 * 1000);
}
function addDays(d, days) {
    return new Date(d.getTime() + days * 24 * 60 * 60 * 1000);
}
//# sourceMappingURL=time.js.map