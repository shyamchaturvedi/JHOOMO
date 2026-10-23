"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MIN_AGE = void 0;
exports.ageYears = ageYears;
exports.isAtLeastAge = isAtLeastAge;
exports.ageBand = ageBand;
exports.assertAdult = assertAdult;
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
function istParts(d) {
    const shifted = new Date(d.getTime() + IST_OFFSET_MS);
    return {
        year: shifted.getUTCFullYear(),
        month: shifted.getUTCMonth() + 1,
        day: shifted.getUTCDate(),
    };
}
function ageYears(dob, at = new Date()) {
    const b = istParts(dob);
    const n = istParts(at);
    let age = n.year - b.year;
    if (n.month < b.month || (n.month === b.month && n.day < b.day))
        age -= 1;
    return age;
}
function isAtLeastAge(dob, minAge, at = new Date()) {
    if (Number.isNaN(dob.getTime()))
        return false;
    return ageYears(dob, at) >= minAge;
}
function ageBand(dob) {
    const age = ageYears(dob);
    if (age < 25)
        return '18-24';
    if (age < 35)
        return '25-34';
    if (age < 45)
        return '35-44';
    return '45+';
}
exports.MIN_AGE = 18;
function assertAdult(dob, at = new Date()) {
    if (!isAtLeastAge(dob, exports.MIN_AGE, at)) {
        throw new Error('AGE_RESTRICTED');
    }
}
//# sourceMappingURL=age.js.map