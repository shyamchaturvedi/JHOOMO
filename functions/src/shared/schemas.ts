import { z } from 'zod';

export const phoneSchema = z
  .string()
  .regex(/^\+91[6-9]\d{9}$/, 'Enter a valid 10-digit Indian mobile number');

export const idSchema = z.string().min(1).max(128);
export const eventIdSchema = z.string().min(1).max(64);
export const tierIdSchema = z.string().min(1).max(64);

export const paiseSchema = z.number().int().min(0);

export const paginationSchema = z.object({
  limit: z.number().int().min(1).max(50).default(20),
  cursor: z.string().max(512).optional(),
});

export const consentTypeSchema = z.enum(['terms', 'privacy', 'marketing', 'radar', 'location', 'sos']);

export const genderSchema = z.enum(['male', 'female', 'nonbinary', 'undisclosed']);

export const panSchema = z
  .string()
  .regex(/^[A-Z]{5}[0-9]{4}[A-Z]$/, 'Invalid PAN format');

export const ifscSchema = z
  .string()
  .regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, 'Invalid IFSC');

export const pincodeSchema = z
  .string()
  .regex(/^[1-9][0-9]{5}$/, 'Invalid PIN code');

export const dobSchema = z.union([
  z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Invalid date'),
  z.number().int().positive(),
]);

export const promoCodeSchema = z
  .string()
  .trim()
  .toUpperCase()
  .min(3)
  .max(24)
  .regex(/^[A-Z0-9_-]+$/, 'Invalid promo code');

export const passcodeSchema = z.string().regex(/^\d{6}$/, 'Passcode must be 6 digits');

export const geoPointSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

export const accuracyM = z.number().min(0).max(100_000).optional();

export const isoDate = z.union([z.string().min(4).max(40), z.number().int().positive()]);

export function parseOrNull<T>(schema: z.ZodType<T>, value: unknown): T | null {
  const result = schema.safeParse(value);
  return result.success ? result.data : null;
}
