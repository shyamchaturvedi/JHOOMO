import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthProvider';

interface NavItem {
  to: string;
  label: string;
  minLevel?: 'L1' | 'L2' | 'L3';
}

const NAV: NavItem[] = [
  { to: '/', label: 'Dashboard' },
  { to: '/kyc', label: 'KYC Review', minLevel: 'L2' },
  { to: '/events', label: 'Event Review', minLevel: 'L2' },
  { to: '/refunds', label: 'Refunds', minLevel: 'L1' },
  { to: '/settlements', label: 'Settlements', minLevel: 'L1' },
  { to: '/reports', label: 'Users & Reports', minLevel: 'L2' },
  { to: '/promoters', label: 'Promoters', minLevel: 'L2' },
  { to: '/support', label: 'Support Desk' },
  { to: '/config', label: 'App Config', minLevel: 'L3' },
  { to: '/audit', label: 'Audit Log', minLevel: 'L2' },
];

export function Layout() {
  const { user, signOutAdmin, can } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark" style={{ background: '#E11D48', color: '#fff' }}>JH</span>
          <div>
            <strong style={{ letterSpacing: '0.5px' }}>JHOOMO Admin</strong>
            <small>Operations Console</small>
          </div>
        </div>
        <nav>
          {NAV.filter((item) => !item.minLevel || can(item.minLevel)).map((item) => (
            <NavLink key={item.to} to={item.to} end={item.to === '/'}>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="muted small">
            {user?.email}
            <br />
            Level {user?.level}
          </div>
          <button
            className="btn btn-ghost"
            onClick={async () => {
              await signOutAdmin();
              navigate('/login');
            }}
          >
            Sign out
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
