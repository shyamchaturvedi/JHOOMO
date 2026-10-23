import {
  createPrivateKey,
  createPublicKey,
  generateKeyPairSync,
  sign as cryptoSign,
  verify as cryptoVerify,
} from 'node:crypto';
import { b64url } from './crypto';

export interface GateKeyPair {
  publicKeyB64: string;
  privateKeyPem: string;
}

/** Per-event Ed25519 keypair used to sign offline gate QR payloads. */
export function generateEventGateKeyPair(): GateKeyPair {
  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  return {
    publicKeyB64: publicKey.export({ type: 'spki', format: 'der' }).toString('base64'),
    privateKeyPem: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
  };
}

export function signOfflineQr(privateKeyPem: string, ticketId: string, eventId: string, ts: number): string {
  const key = createPrivateKey(privateKeyPem);
  return b64url(cryptoSign(null, Buffer.from(`${ticketId}|${eventId}|${ts}`), key));
}

export function verifyOfflineQr(
  publicKeyB64: string,
  ticketId: string,
  eventId: string,
  ts: number,
  signature: string,
): boolean {
  try {
    const key = createPublicKey({
      key: Buffer.from(publicKeyB64, 'base64'),
      format: 'der',
      type: 'spki',
    });
    return cryptoVerify(
      null,
      Buffer.from(`${ticketId}|${eventId}|${ts}`),
      key,
      Buffer.from(signature, 'base64url'),
    );
  } catch {
    return false;
  }
}

export function buildOfflinePayload(
  ticketId: string,
  eventId: string,
  ts: number,
  signature: string,
): string {
  return `MILO1S.${eventId}.${ticketId}.${ts}.${signature}`;
}

export function buildStaticOfflinePayload(ticketId: string, eventId: string, signature: string): string {
  return `MILO1S.${eventId}.${ticketId}.${signature}`;
}

export interface ParsedQrPayload {
  kind: 'dynamic' | 'static' | 'unknown';
  eventId?: string;
  ticketId: string;
  ts?: number;
  signature: string;
}

export function parseQrPayload(payload: string): ParsedQrPayload | null {
  const parts = payload.trim().split('.');
  if (parts[0] === 'MILO1' && parts.length === 4) {
    return { kind: 'dynamic', ticketId: parts[1]!, ts: Number(parts[2]), signature: parts[3]! };
  }
  if (parts[0] === 'MILO1S' && parts.length === 5) {
    return {
      kind: 'static',
      eventId: parts[1]!,
      ticketId: parts[2]!,
      ts: Number(parts[3]),
      signature: parts[4]!,
    };
  }
  if (parts[0] === 'MILO1S' && parts.length === 4) {
    return { kind: 'static', eventId: parts[1]!, ticketId: parts[2]!, signature: parts[3]! };
  }
  return null;
}
