import { useState } from 'react';
import { useAuth } from '../auth/AuthProvider';

export function Login() {
  const { signIn, error, loading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);

  return (
    <div className="login-wrap">
      <form
        className="login-card"
        onSubmit={async (event) => {
          event.preventDefault();
          setBusy(true);
          try {
            await signIn(email, password);
          } catch {
            /* error surfaced by provider */
          } finally {
            setBusy(false);
          }
        }}
      >
        <div className="brand">
          <span className="brand-mark">M</span>
          <div>
            <strong>Milo Console</strong>
            <small>Super Admin</small>
          </div>
        </div>
        <label>
          Email
          <input
            type="email"
            value={email}
            autoComplete="username"
            required
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            autoComplete="current-password"
            required
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        {error ? <div className="error-box">{error}</div> : null}
        <button className="btn btn-primary" type="submit" disabled={busy || loading}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
        <p className="muted small">
          Sessions are 8 hours. Five failed attempts locks the account. All actions are audit logged.
        </p>
      </form>
    </div>
  );
}
