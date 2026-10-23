"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminApp = adminApp;
exports.db = db;
exports.authAdmin = authAdmin;
exports.storageAdmin = storageAdmin;
exports.messaging = messaging;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const auth_1 = require("firebase-admin/auth");
const storage_1 = require("firebase-admin/storage");
const messaging_1 = require("firebase-admin/messaging");
function adminApp() {
    if ((0, app_1.getApps)().length > 0)
        return (0, app_1.getApps)()[0];
    return (0, app_1.initializeApp)();
}
function db() {
    return (0, firestore_1.getFirestore)(adminApp());
}
function authAdmin() {
    return (0, auth_1.getAuth)(adminApp());
}
function storageAdmin() {
    return (0, storage_1.getStorage)(adminApp());
}
function messaging() {
    return (0, messaging_1.getMessaging)(adminApp());
}
//# sourceMappingURL=admin.js.map