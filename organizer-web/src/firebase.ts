import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyANThDrjMQpbrIMTnYsb0BS3VPo0PYutRo",
  authDomain: "milo-da65c.firebaseapp.com",
  projectId: "milo-da65c",
  storageBucket: "milo-da65c.firebasestorage.app",
  messagingSenderId: "367531407467",
  appId: "1:367531407467:web:8c43bb9b0749268b5a7689"
};

export const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
