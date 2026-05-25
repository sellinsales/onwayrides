window.ONWAYRIDES_WEB_CONFIG = {
  apiBaseUrl:
    window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1"
      ? "http://127.0.0.1:8000/api"
      : window.location.hostname.endsWith("onwayrides.com")
        ? "https://api.onwayrides.com/api"
        : `${window.location.origin}/api`,
  supportEmail: "support@onwayrides.com",
  supportPhone: "+46793000786",
  whatsappBusinessNumber: "+46793000786",
  whatsappChannelUrl: "",
  firebase: {
    apiKey: "AIzaSyCtZYFp9a3-Wl_4ykpC-erNuMsFb2EUFvs",
    authDomain: "onwayrides.firebaseapp.com",
    projectId: "onwayrides",
    storageBucket: "onwayrides.firebasestorage.app",
    messagingSenderId: "867042633205",
    appId: "1:867042633205:web:0540cb61e238caf22facbc",
    measurementId: "G-V9T4Y37VCT",
  },
};
