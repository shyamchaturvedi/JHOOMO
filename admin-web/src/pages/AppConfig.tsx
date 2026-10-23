import { useEffect, useState } from 'react';
import { PageHeader, Panel, Loading, ErrorBox } from '../components/ui';
import { call } from '../lib/api';
import { useCallable } from '../lib/useCallable';

interface ConfigPayload {
  public: Record<string, unknown>;
  fees: Record<string, unknown>;
  limits: Record<string, unknown>;
}

export function AppConfig() {
  const { data, loading, error, reload } = useCallable<ConfigPayload>(() => call('adminGetConfig', {}), []);
  const [draft, setDraft] = useState<Record<string, Record<string, string>>>({});
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (!data) return;
    const next: Record<string, Record<string, string>> = {};
    for (const scope of ['public', 'fees', 'limits'] as const) {
      next[scope] = Object.fromEntries(
        Object.entries(data[scope] ?? {}).map(([k, v]) => [k, typeof v === 'object' ? JSON.stringify(v) : String(v)]),
      );
    }
    setDraft(next);
  }, [data]);

  async function save(scope: 'public' | 'fees' | 'limits') {
    setBusy(true);
    setActionError(null);
    setSaved(false);
    try {
      const patch: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(draft[scope] ?? {})) {
        if (key === 'version' || key === 'updatedBy' || key === 'updatedAt') continue;
        const asNumber = Number(value);
        patch[key] = value.trim() !== '' && !Number.isNaN(asNumber) ? asNumber : value;
      }
      await call('adminUpdateConfig', { scope, patch, reason: 'Console edit' });
      setSaved(true);
      reload();
    } catch (err) {
      setActionError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  if (loading) return <Loading />;

  return (
    <>
      <PageHeader
        title="App config & feature flags"
        subtitle="Changes are versioned and audit logged. Kill-switches take effect on the next app launch."
      />
      <ErrorBox message={error ?? actionError} />
      {saved ? <div className="ok-box">Saved.</div> : null}

      <div className="grid-2">
        {(['fees', 'limits', 'public'] as const).map((scope) => (
          <Panel key={scope}>
            <h3>{scope}</h3>
            <div className="form-grid">
              {Object.entries(draft[scope] ?? {}).map(([key, value]) => (
                <label key={key}>
                  {key}
                  <input
                    value={value}
                    disabled={['version', 'updatedBy', 'updatedAt'].includes(key)}
                    onChange={(e) =>
                      setDraft((prev) => ({ ...prev, [scope]: { ...prev[scope], [key]: e.target.value } }))
                    }
                  />
                </label>
              ))}
            </div>
            <button className="btn btn-primary" disabled={busy} onClick={() => void save(scope)}>
              {busy ? 'Saving…' : `Save ${scope}`}
            </button>
          </Panel>
        ))}
      </div>
    </>
  );
}
