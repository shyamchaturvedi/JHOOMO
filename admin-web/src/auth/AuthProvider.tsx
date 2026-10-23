import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  getIdTokenResult,
} from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { getFirestore } from 'firebase/firestore';
import { auth, firebaseApp } from '../lib/firebase';

export type AdminLevel = 'L1' | 'L2' | 'L3';

interface AdminUser {
  uid: string;
  email: string;
  level: AdminLevel;
  active: boolean;
}

interface AuthState {
  user: AdminUser | null;
  loading: boolean;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOutAdmin: () => Promise<void>;
  can: (level: AdminLevel) => boolean;
}

const AuthContext = createContext<AuthState | null>(null);

const RANK: Record<AdminLevel, number> = { L1: 1, L2: 2, L3: 3 };

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      setLoading(true);
      try {
        if (!firebaseUser) {
          setUser(null);
          return;
        }
        const token = await getIdTokenResult(firebaseUser, true);
        const claimLevel = (token.claims.adminLevel as AdminLevel | undefined) ?? 'L1';
        const isAdmin = token.claims.admin === true;

        const db = getFirestore(firebaseApp);
        const adminSnap = await getDoc(doc(db, 'admins', firebaseUser.uid));
        const adminData = adminSnap.exists() ? adminSnap.data() : undefined;

        if (!isAdmin && !adminData) {
          setUser(null);
          setError('This account is not registered as a Milo admin.');
          return;
        }

        setUser({
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          level: (adminData?.level as AdminLevel | undefined) ?? claimLevel,
          active: adminData?.active !== false,
        });
      } finally {
        setLoading(false);
      }
    });
    return unsubscribe;
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      loading,
      error,
      signIn: async (email: string, password: string) => {
        setError(null);
        try {
          await signInWithEmailAndPassword(auth, email, password);
        } catch (err) {
          const e = err as { code?: string };
          const message =
            e.code === 'auth/invalid-credential'
              ? 'Invalid email or password.'
              : e.code === 'auth/too-many-requests'
                ? 'Too many attempts. Try again later.'
                : 'Sign-in failed.';
          setError(message);
          throw err;
        }
      },
      signOutAdmin: async () => {
        await signOut(auth);
        setUser(null);
      },
      can: (level: AdminLevel) => (user ? RANK[user.level] >= RANK[level] : false),
    }),
    [user, loading, error],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
