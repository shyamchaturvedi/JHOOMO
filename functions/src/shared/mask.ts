/**
 * Privacy helpers for showing a member's identity before a mutual match.
 *
 * PRD rule: a member is only ever shown as "First name + last initial".
 * Full names are revealed only inside a DM that both sides accepted.
 */
export function maskDisplayName(name: unknown): string {
  const raw = String(name ?? '').trim();
  if (!raw) return 'Milo User';

  const parts = raw.split(/\s+/).filter(Boolean);
  const first = parts[0] ?? 'Milo';
  if (parts.length === 1) return first;

  const lastInitial = parts[parts.length - 1]!.charAt(0).toUpperCase();
  return `${first} ${lastInitial}.`;
}
