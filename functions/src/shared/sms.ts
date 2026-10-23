import { logger } from 'firebase-functions';

export interface SmsResult {
  ok: boolean;
  providerMessageId?: string;
  error?: string;
}

/**
 * Sends an SMS through the configured DLT-registered provider.
 *
 * The provider is intentionally abstracted: Milo only requires a DLT template
 * id and a registered sender id for every outbound message. Without a
 * provider configured the call fails closed (safety notifications must never
 * silently disappear) but the error is surfaced to the caller.
 */
export async function sendSms(
  to: string,
  templateId: string,
  templateParams: string[],
): Promise<SmsResult> {
  const baseUrl = process.env.SMS_PROVIDER_BASE_URL;
  const apiKey = process.env.SMS_PROVIDER_API_KEY;
  const senderId = process.env.SMS_DLT_SENDER_ID;

  if (!baseUrl || !apiKey || !senderId) {
    logger.error('sms.provider_not_configured', { templateId, to: maskPhone(to) });
    return { ok: false, error: 'sms_provider_not_configured' };
  }

  const digits = to.replace(/\D/g, '');
  if (digits.length < 10) return { ok: false, error: 'invalid_number' };

  try {
    const res = await fetch(`${baseUrl.replace(/\/$/, '')}/sms`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        to: `+91${digits.slice(-10)}`,
        senderId,
        templateId,
        params: templateParams,
        dltTemplateId: templateId,
      }),
    });

    if (!res.ok) {
      const text = await res.text();
      logger.error('sms.failed', { templateId, status: res.status, body: text.slice(0, 200) });
      return { ok: false, error: `provider_${res.status}` };
    }

    const body = (await res.json()) as { messageId?: string };
    return { ok: true, providerMessageId: body.messageId };
  } catch (err) {
    logger.error('sms.exception', { templateId, error: err instanceof Error ? err.message : String(err) });
    return { ok: false, error: 'provider_exception' };
  }
}

export function maskPhone(phone: string | null | undefined): string {
  if (!phone) return '***';
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 4) return '***';
  return `+91 XXXXX X${digits.slice(-3)}`;
}
