import { App, getApps, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { Auth, getAuth } from 'firebase-admin/auth';
import { Storage, getStorage } from 'firebase-admin/storage';
import { getMessaging } from 'firebase-admin/messaging';

export function adminApp(): App {
  if (getApps().length > 0) return getApps()[0]!;
  return initializeApp();
}

export function db(): Firestore {
  return getFirestore(adminApp());
}

export function authAdmin(): Auth {
  return getAuth(adminApp());
}

export function storageAdmin(): Storage {
  return getStorage(adminApp());
}

export function messaging() {
  return getMessaging(adminApp());
}
