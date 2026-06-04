importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCvVIQJi-JZYV1b-J6epUDJtoVP040_7Oo",
  authDomain: "inmakes-87ea0.firebaseapp.com",
  projectId: "inmakes-87ea0",
  storageBucket: "inmakes-87ea0.firebasestorage.app",
  messagingSenderId: "804369840655",
  appId: "1:804369840655:web:f57ff61d51fe5fd539c17a",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Background message:", payload);

  self.registration.showNotification(
    payload.notification?.title ?? "Notification",
    {
      body: payload.notification?.body ?? "",
      icon: "/branding/app_logo.png",
    }
  );
});