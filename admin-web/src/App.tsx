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

function Protected() {
  const { user, loading } = useAuth();
  if (loading) return <Loading />;
  if (!user) return <Navigate to="/login" replace />;
  return <Layout />;
}

export function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route element={<Protected />}>
          <Route index element={<Dashboard />} />
          <Route path="kyc" element={<KycQueue />} />
          <Route path="events" element={<EventReview />} />
          <Route path="refunds" element={<Refunds />} />
          <Route path="settlements" element={<Settlements />} />
          <Route path="reports" element={<UsersReports />} />
          <Route path="promoters" element={<Promoters />} />
          <Route path="support" element={<SupportDesk />} />
          <Route path="config" element={<AppConfig />} />
          <Route path="audit" element={<AuditLog />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthProvider>
  );
}
