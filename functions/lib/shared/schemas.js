"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isoDate = exports.accuracyM = exports.geoPointSchema = exports.passcodeSchema = exports.promoCodeSchema = exports.dobSchema = exports.pincodeSchema = exports.ifscSchema = exports.panSchema = exports.genderSchema = exports.consentTypeSchema = exports.paginationSchema = exports.paiseSchema = exports.tierIdSchema = exports.eventIdSchema = exports.idSchema = exports.phoneSchema = void 0;
exports.parseOrNull = parseOrNull;
const zod_1 = require("zod");
exports.phoneSchema = zod_1.z
    .string()
    .regex(/^\+91[6-9]\d{9}$/, 'Enter a valid 10-digit Indian mobile number');
exports.idSchema = zod_1.z.string().min(1).max(128);
exports.eventIdSchema = zod_1.z.string().min(1).max(64);
exports.tierIdSchema = zod_1.z.string().min(1).max(64);
exports.paiseSchema = zod_1.z.number().int().min(0);
exports.paginationSchema = zod_1.z.object({
    limit: zod_1.z.number().int().min(1).max(50).default(20),
    cursor: zod_1.z.string().max(512).optional(),
});
exports.consentTypeSchema = zod_1.z.enum(['terms', 'privacy', 'marketing', 'radar', 'location', 'sos']);
exports.genderSchema = zod_1.z.enum(['male', 'female', 'nonbinary', 'undisclosed']);
exports.panSchema = zod_1.z
    .string()
    .regex(/^[A-Z]{5}[0-9]{4}[A-Z]$/, 'Invalid PAN format');
exports.ifscSchema = zod_1.z
    .string()
    .regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, 'Invalid IFSC');
exports.pincodeSchema = zod_1.z
    .string()
    .regex(/^[1-9][0-9]{5}$/, 'Invalid PIN code');
exports.dobSchema = zod_1.z.union([
    zod_1.z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date'),
    zod_1.z.number().int().positive(),
]);
exports.promoCodeSchema = zod_1.z
    .string()
    .trim()
    .toUpperCase()
    .min(3)
    .max(24)
    .regex(/^[A-Z0-9_-]+$/, 'Invalid promo code');
exports.passcodeSchema = zod_1.z.string().regex(/^\d{6}$/, 'Passcode must be 6 digits');
exports.geoPointSchema = zod_1.z.object({
    lat: zod_1.z.number().min(-90).max(90),
    lng: zod_1.z.number().min(-180).max(180),
});
exports.accuracyM = zod_1.z.number().min(0).max(100_000).optional();
exports.isoDate = zod_1.z.union([zod_1.z.string().min(4).max(40), zod_1.z.number().int().positive()]);
function parseOrNull(schema, value) {
    const result = schema.safeParse(value);
    return result.success ? result.data : null;
}
//# sourceMappingURL=schemas.js.map