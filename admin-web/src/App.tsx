import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthProvider';
import { Layout } from './components/Layout';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { KycQueue } from './pages/KycQueue';
import { EventReview } from './pages/EventReview';
import { Refunds } from './pages/Refunds';
import { Settlements } from './pages/Settlements';
import { UsersReports } from './pages/UsersReports';
import { Promoters } from './pages/Promoters';
import { AppConfig } from './pages/AppConfig';
import { AuditLog } from './pages/AuditLog';
import { SupportDesk } from './pages/SupportDesk';
import { Loading } from './components/ui';
import type { ReactNode } from 'react';

function Protected() {
  const { user, loading } = useAuth();
  if (loading) return <Loading />;
  if (!user) return <Navigate to="/login" replace />;
  return <Layout />;
}

function RequireLevel({ level, children }: { level: 'L1' | 'L2' | 'L3'; children: ReactNode }) {
  const { can } = useAuth();
  return can(level) ? <>{children}</> : <Navigate to="/" replace />;
}

export function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route element={<Protected />}>
          <Route index element={<Dashboard />} />
          <Route path="kyc" element={<RequireLevel level="L2"><KycQueue /></RequireLevel>} />
          <Route path="events" element={<RequireLevel level="L2"><EventReview /></RequireLevel>} />
          <Route path="refunds" element={<RequireLevel level="L1"><Refunds /></RequireLevel>} />
          <Route path="settlements" element={<RequireLevel level="L1"><Settlements /></RequireLevel>} />
          <Route path="reports" element={<RequireLevel level="L2"><UsersReports /></RequireLevel>} />
          <Route path="promoters" element={<RequireLevel level="L2"><Promoters /></RequireLevel>} />
          <Route path="support" element={<SupportDesk />} />
          <Route path="config" element={<RequireLevel level="L3"><AppConfig /></RequireLevel>} />
          <Route path="audit" element={<RequireLevel level="L2"><AuditLog /></RequireLevel>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  );
}
