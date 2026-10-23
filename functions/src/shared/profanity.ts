const BLOCKLIST = [
  'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'cunt', 'dick', 'slut', 'whore',
  'chutiya', 'madarchod', 'bhosdi', 'randi', 'gandu', 'kutta', 'kutiya', 'sex',
];

const LINK_PATTERN = /(https?:\/\/|www\.)[^\s]+/i;
const PHONE_PATTERN = /(\+?\d[\d\s-]{8,}\d)/;
const UPI_PATTERN = /[\w.\-]{2,}@[a-zA-Z]{2,}/;

export interface TextCheck {
  clean: boolean;
  hasLink: boolean;
  hasPhone: boolean;
  hasUpi: boolean;
  masked?: string;
}

/**
 * Lightweight abuse filter for chat content. It masks rather than blocks
 * profanity so moderators keep context, and reports links / contact details
 * so the client can warn the sender before the message is written.
 */
export function checkText(text: string): TextCheck {
  let masked = text;
  let clean = true;

  for (const word of BLOCKLIST) {
    const regex = new RegExp(`\\b${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\w*\\b`, 'gi');
    if (regex.test(masked)) {
      masked = masked.replace(regex, (match) => '*'.repeat(Math.min(match.length, 8)));
      clean = false;
    }
  }

  const hasLink = LINK_PATTERN.test(text);
  const hasPhone = PHONE_PATTERN.test(text);
  const hasUpi = UPI_PATTERN.test(text);

  return {
    clean,
    hasLink,
    hasPhone,
    hasUpi,
    masked: clean ? undefined : masked,
  };
}

export function containsBlockedContent(text: string): boolean {
  return !checkText(text).clean;
}
