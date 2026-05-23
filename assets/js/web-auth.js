import {
  GoogleAuthProvider,
  RecaptchaVerifier,
  browserLocalPersistence,
  createUserWithEmailAndPassword,
  getAuth,
  linkWithPhoneNumber,
  onAuthStateChanged,
  setPersistence,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
} from "https://www.gstatic.com/firebasejs/12.7.0/firebase-auth.js";
import { initializeApp } from "https://www.gstatic.com/firebasejs/12.7.0/firebase-app.js";

const config = window.ONWAYRIDES_WEB_CONFIG ?? {};
const app = initializeApp(config.firebase ?? {});
const auth = getAuth(app);
await setPersistence(auth, browserLocalPersistence);

const authScreen = document.querySelector("#auth-screen");
const onboardingScreen = document.querySelector("#onboarding-screen");
const accountScreen = document.querySelector("#account-screen");
const emailAuthForm = document.querySelector("#email-auth-form");
const authError = document.querySelector("#auth-error");
const registerButton = document.querySelector("#register-button");
const googleSigninButton = document.querySelector("#google-signin-button");
const onboardingForm = document.querySelector("#onboarding-form");
const onboardingError = document.querySelector("#onboarding-error");
const onboardingSuccess = document.querySelector("#onboarding-success");
const sendOtpButton = document.querySelector("#send-otp-button");
const verifyOtpButton = document.querySelector("#verify-otp-button");
const phoneStatusPill = document.querySelector("#phone-status-pill");
const accountDataGrid = document.querySelector("#account-data-grid");
const openWhatsAppButton = document.querySelector("#open-whatsapp-button");
const followChannelButton = document.querySelector("#follow-channel-button");
const signoutButtonOnboarding = document.querySelector("#signout-button-onboarding");
const signoutButtonAccount = document.querySelector("#signout-button-account");

document.querySelectorAll("[data-whatsapp-number]").forEach((slot) => {
  slot.textContent = config.whatsappBusinessNumber ?? "";
});

let confirmationResult = null;
let recaptchaVerifier = null;
let verifiedPhone = null;
let lastSession = null;

function showAuthError(message) {
  authError.hidden = !message;
  authError.textContent = message ?? "";
}

function showOnboardingError(message) {
  onboardingError.hidden = !message;
  onboardingError.textContent = message ?? "";
}

function showOnboardingSuccess(message) {
  onboardingSuccess.hidden = !message;
  onboardingSuccess.textContent = message ?? "";
}

function setScreen(screen) {
  authScreen.hidden = screen !== "auth";
  onboardingScreen.hidden = screen !== "onboarding";
  accountScreen.hidden = screen !== "account";
}

function buildApiUrl(path) {
  return `${String(config.apiBaseUrl ?? "").replace(/\/$/, "")}${path}`;
}

async function withIdToken(callback) {
  const user = auth.currentUser;
  if (!user) {
    throw new Error("Sign in required.");
  }

  const idToken = await user.getIdToken(true);
  return callback(idToken);
}

async function syncLogin(context = {}) {
  return withIdToken(async (idToken) => {
    const response = await fetch(buildApiUrl("/auth/login"), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({
        platform: "web",
        ...context,
      }),
    });

    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.message ?? "Unable to sync your OnWay Rides account.");
    }

    return payload;
  });
}

async function completeOnboarding(payload) {
  return withIdToken(async (idToken) => {
    const response = await fetch(buildApiUrl("/auth/onboarding"), {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify(payload),
    });

    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.message ?? "Unable to save your onboarding details.");
    }

    return data;
  });
}

function normalizeCountryCode(value) {
  const digits = String(value ?? "").replace(/\D+/g, "").replace(/^0+/, "");
  return `+${digits}`;
}

function normalizePhone(countryCode, phone) {
  const cc = normalizeCountryCode(countryCode).replace("+", "");
  const local = String(phone ?? "").replace(/\D+/g, "").replace(/^0+/, "");

  if (local.startsWith(cc)) {
    return `+${local}`;
  }

  return `+${cc}${local}`;
}

function updatePhoneStatus(status, text) {
  phoneStatusPill.className = `pill ${status}`;
  phoneStatusPill.textContent = text;
}

function populateOnboarding(session) {
  const user = session.user ?? {};
  const consents = session.consents ?? {};

  document.querySelector("#onboarding-full-name").value = user.full_name ?? "";
  document.querySelector("#onboarding-country-code").value = user.country_code ?? "+92";
  document.querySelector("#onboarding-phone").value = user.phone ? user.phone.replace(user.country_code ?? "", "") : "";
  document.querySelector("#accept-privacy").checked = Boolean(consents.privacy_policy_accepted_at);
  document.querySelector("#accept-terms").checked = Boolean(consents.terms_of_service_accepted_at);
  document.querySelector("#whatsapp-opt-in").checked = Boolean(consents.whatsapp_marketing_opt_in);
  document.querySelector("#sms-opt-in").checked = Boolean(consents.sms_marketing_opt_in);

  if (user.phone_verified_at) {
    verifiedPhone = user.phone;
    updatePhoneStatus("good", "Phone verified");
  } else {
    verifiedPhone = null;
    updatePhoneStatus("warn", "Phone not verified");
  }
}

function renderAccount(session) {
  const user = session.user ?? {};
  const consents = session.consents ?? {};
  const beta = session.beta ?? {};
  const fields = [
    ["Full name", user.full_name ?? "Not set"],
    ["Email", user.email ?? "Not set"],
    ["Phone", user.phone ?? "Not set"],
    ["Phone verified", user.phone_verified_at ? "Yes" : "No"],
    ["WhatsApp marketing", consents.whatsapp_marketing_opt_in ? "Opted in" : "Not opted in"],
    ["SMS marketing", consents.sms_marketing_opt_in ? "Opted in" : "Not opted in"],
    ["Role", user.role ?? "rider"],
    ["Beta rides per day", String(beta.daily_rides_limit ?? 3)],
  ];

  accountDataGrid.innerHTML = fields
    .map(
      ([label, value]) => `
        <div class="account-data">
          <strong>${label}</strong>
          <span>${value}</span>
        </div>
      `,
    )
    .join("");

  const businessNumber = String(config.whatsappBusinessNumber ?? "").replace(/[^\d]/g, "");
  openWhatsAppButton.href = `https://wa.me/${businessNumber}?text=${encodeURIComponent("Hello OnWay Rides, I want travel updates on my account.")}`;
  followChannelButton.href = config.whatsappChannelUrl || "#";
  followChannelButton.toggleAttribute("aria-disabled", !config.whatsappChannelUrl || config.whatsappChannelUrl.includes("replace-me"));
}

async function refreshSession() {
  try {
    const session = await syncLogin();
    lastSession = session;

    if (session.requirements?.profile_complete) {
      renderAccount(session);
      setScreen("account");
      return;
    }

    populateOnboarding(session);
    setScreen("onboarding");
  } catch (error) {
    showAuthError(error.message);
    setScreen("auth");
  }
}

async function handleEmailAuth(event, mode = "signin") {
  event.preventDefault();
  showAuthError("");

  const formData = new FormData(emailAuthForm);
  const fullName = String(formData.get("full_name") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    showAuthError("Email and password are required.");
    return;
  }

  try {
    if (mode === "register") {
      await createUserWithEmailAndPassword(auth, email, password);
    } else {
      await signInWithEmailAndPassword(auth, email, password);
    }

    await syncLogin({
      full_name: fullName || undefined,
      role: "rider",
      platform: "web",
    });
    await refreshSession();
  } catch (error) {
    showAuthError(error.message ?? "Unable to authenticate.");
  }
}

async function handleGoogleAuth() {
  showAuthError("");

  try {
    const provider = new GoogleAuthProvider();
    await signInWithPopup(auth, provider);
    await syncLogin({
      role: "rider",
      platform: "web",
    });
    await refreshSession();
  } catch (error) {
    showAuthError(error.message ?? "Unable to sign in with Google.");
  }
}

async function ensureRecaptcha() {
  if (recaptchaVerifier) {
    return recaptchaVerifier;
  }

  recaptchaVerifier = new RecaptchaVerifier(auth, "recaptcha-container", {
    size: "normal",
  });
  await recaptchaVerifier.render();
  return recaptchaVerifier;
}

async function sendOtp() {
  showOnboardingError("");
  showOnboardingSuccess("");

  const user = auth.currentUser;
  if (!user) {
    showOnboardingError("Sign in again to continue.");
    return;
  }

  const countryCode = document.querySelector("#onboarding-country-code").value;
  const phone = document.querySelector("#onboarding-phone").value;
  const e164Phone = normalizePhone(countryCode, phone);

  if (!/^\+\d{10,15}$/.test(e164Phone)) {
    showOnboardingError("Enter a valid phone number before requesting an OTP.");
    return;
  }

  if (user.phoneNumber === e164Phone) {
    verifiedPhone = e164Phone;
    updatePhoneStatus("good", "Phone verified");
    showOnboardingSuccess("This phone number is already verified in Firebase.");
    return;
  }

  try {
    const verifier = await ensureRecaptcha();
    confirmationResult = await linkWithPhoneNumber(user, e164Phone, verifier);
    updatePhoneStatus("warn", "OTP sent");
    showOnboardingSuccess(`OTP sent to ${e164Phone}. Enter the code to verify.`);
  } catch (error) {
    showOnboardingError(error.message ?? "Unable to send OTP right now.");
  }
}

async function verifyOtp() {
  showOnboardingError("");
  showOnboardingSuccess("");

  if (!confirmationResult) {
    showOnboardingError("Request an OTP before verifying the code.");
    return;
  }

  const code = document.querySelector("#otp-code").value.trim();
  if (!code) {
    showOnboardingError("Enter the OTP code you received.");
    return;
  }

  try {
    const credentialResult = await confirmationResult.confirm(code);
    verifiedPhone = credentialResult.user.phoneNumber ?? verifiedPhone;
    updatePhoneStatus("good", "Phone verified");
    showOnboardingSuccess("Phone number verified successfully.");
  } catch (error) {
    showOnboardingError(error.message ?? "Unable to verify the OTP code.");
  }
}

async function saveOnboarding(event) {
  event.preventDefault();
  showOnboardingError("");
  showOnboardingSuccess("");

  const fullName = document.querySelector("#onboarding-full-name").value.trim();
  const countryCode = document.querySelector("#onboarding-country-code").value.trim();
  const phone = document.querySelector("#onboarding-phone").value.trim();
  const acceptPrivacy = document.querySelector("#accept-privacy").checked;
  const acceptTerms = document.querySelector("#accept-terms").checked;
  const whatsappOptIn = document.querySelector("#whatsapp-opt-in").checked;
  const smsOptIn = document.querySelector("#sms-opt-in").checked;
  const e164Phone = normalizePhone(countryCode, phone);

  if (!verifiedPhone || verifiedPhone !== e164Phone) {
    showOnboardingError("Verify the exact phone number you want to save before continuing.");
    return;
  }

  if (!acceptPrivacy || !acceptTerms) {
    showOnboardingError("Privacy Policy and Terms of Service must be accepted.");
    return;
  }

  try {
    const session = await completeOnboarding({
      full_name: fullName,
      country_code: countryCode,
      phone,
      accept_privacy_policy: acceptPrivacy,
      accept_terms: acceptTerms,
      whatsapp_marketing_opt_in: whatsappOptIn,
      sms_marketing_opt_in: smsOptIn,
    });

    lastSession = session;
    renderAccount(session);
    setScreen("account");
  } catch (error) {
    showOnboardingError(error.message ?? "Unable to save your profile.");
  }
}

async function signOutEverywhere() {
  confirmationResult = null;
  verifiedPhone = null;
  lastSession = null;
  await signOut(auth);
  setScreen("auth");
}

emailAuthForm?.addEventListener("submit", (event) => handleEmailAuth(event, "signin"));
registerButton?.addEventListener("click", (event) => handleEmailAuth(event, "register"));
googleSigninButton?.addEventListener("click", handleGoogleAuth);
sendOtpButton?.addEventListener("click", sendOtp);
verifyOtpButton?.addEventListener("click", verifyOtp);
onboardingForm?.addEventListener("submit", saveOnboarding);
signoutButtonOnboarding?.addEventListener("click", signOutEverywhere);
signoutButtonAccount?.addEventListener("click", signOutEverywhere);

onAuthStateChanged(auth, async (user) => {
  showAuthError("");
  showOnboardingError("");
  showOnboardingSuccess("");

  if (!user) {
    setScreen("auth");
    return;
  }

  await refreshSession();
});
