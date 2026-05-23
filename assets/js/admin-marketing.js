import {
  GoogleAuthProvider,
  browserLocalPersistence,
  getAuth,
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

const authScreen = document.querySelector("#admin-auth-screen");
const dashboardScreen = document.querySelector("#admin-dashboard-screen");
const authForm = document.querySelector("#admin-auth-form");
const authError = document.querySelector("#admin-auth-error");
const googleButton = document.querySelector("#admin-google-button");
const signoutButton = document.querySelector("#admin-signout-button");
const filterForm = document.querySelector("#marketing-filter-form");
const summaryGrid = document.querySelector("#marketing-summary-grid");
const tableBody = document.querySelector("#marketing-table-body");
const exportButton = document.querySelector("#marketing-export-button");
const marketingError = document.querySelector("#marketing-error");

document.querySelectorAll("[data-whatsapp-number]").forEach((slot) => {
  slot.textContent = config.whatsappBusinessNumber ?? "";
});

function buildApiUrl(path, params = new URLSearchParams()) {
  const base = `${String(config.apiBaseUrl ?? "").replace(/\/$/, "")}${path}`;
  const queryString = params.toString();
  return queryString ? `${base}?${queryString}` : base;
}

async function withIdToken(callback) {
  const user = auth.currentUser;
  if (!user) {
    throw new Error("Admin sign-in required.");
  }

  const idToken = await user.getIdToken(true);
  return callback(idToken);
}

function showAuthError(message) {
  authError.hidden = !message;
  authError.textContent = message ?? "";
}

function showMarketingError(message) {
  marketingError.hidden = !message;
  marketingError.textContent = message ?? "";
}

function setScreen(screen) {
  authScreen.hidden = screen !== "auth";
  dashboardScreen.hidden = screen !== "dashboard";
}

async function syncAdmin() {
  return withIdToken(async (idToken) => {
    const response = await fetch(buildApiUrl("/auth/login"), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({
        platform: "web",
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.message ?? "Unable to verify the admin account.");
    }

    if (!["admin", "support"].includes(data.user?.role)) {
      throw new Error("This account is not allowed to access the marketing audience.");
    }

    return data;
  });
}

function buildParams() {
  const formData = new FormData(filterForm);
  const params = new URLSearchParams();
  for (const [key, value] of formData.entries()) {
    if (String(value).trim()) {
      params.set(key, String(value).trim());
    }
  }
  return params;
}

function renderSummary(summary = {}) {
  const cards = [
    ["Registered users", summary.registered_users ?? 0],
    ["WhatsApp opted in", summary.whatsapp_opted_in ?? 0],
    ["SMS opted in", summary.sms_opted_in ?? 0],
    ["Phone verified", summary.phone_verified ?? 0],
    ["Web sign-ins", summary.web_sign_ins ?? 0],
    ["Android sign-ins", summary.android_sign_ins ?? 0],
  ];

  summaryGrid.innerHTML = cards
    .map(
      ([label, value]) => `
        <article>
          <strong>${value}</strong>
          <span>${label}</span>
        </article>
      `,
    )
    .join("");
}

function renderRows(rows = []) {
  tableBody.innerHTML = rows
    .map((row) => {
      const whatsappPill = row.whatsapp_marketing_opt_in
        ? '<span class="pill good">Opted in</span>'
        : '<span class="pill warn">No</span>';
      const smsPill = row.sms_marketing_opt_in
        ? '<span class="pill good">Opted in</span>'
        : '<span class="pill warn">No</span>';

      return `
        <tr>
          <td>
            <strong>${row.full_name ?? "OnWay User"}</strong><br>
            <span class="helper-text">${row.email ?? "No email"}</span>
          </td>
          <td>
            <strong>${row.phone ?? "No phone"}</strong><br>
            <span class="helper-text">${row.phone_verified ? "Verified" : "Unverified"}</span>
          </td>
          <td>
            <strong>${row.role}</strong><br>
            <span class="helper-text">${row.platform}</span>
          </td>
          <td>${whatsappPill}</td>
          <td>${smsPill}</td>
          <td><span class="helper-text">${row.last_login_at ? new Date(row.last_login_at).toLocaleString() : "Never"}</span></td>
        </tr>
      `;
    })
    .join("");
}

async function loadAudience() {
  showMarketingError("");

  try {
    const params = buildParams();
    const payload = await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl("/admin/marketing/contacts", params), {
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? "Unable to load the marketing audience.");
      }

      return data;
    });

    renderSummary(payload.summary);
    renderRows(payload.data);
    setScreen("dashboard");
  } catch (error) {
    showMarketingError(error.message ?? "Unable to load the marketing audience.");
  }
}

async function handleAuth(event, mode = "email") {
  event.preventDefault();
  showAuthError("");

  try {
    if (mode === "google") {
      await signInWithPopup(auth, new GoogleAuthProvider());
    } else {
      const email = document.querySelector("#admin-email").value.trim();
      const password = document.querySelector("#admin-password").value;
      await signInWithEmailAndPassword(auth, email, password);
    }

    await syncAdmin();
    await loadAudience();
  } catch (error) {
    showAuthError(error.message ?? "Unable to sign in.");
    setScreen("auth");
  }
}

async function exportAudience() {
  showMarketingError("");

  try {
    const params = buildParams();
    await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl("/admin/marketing/contacts/export", params), {
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.message ?? "Unable to export the marketing audience.");
      }

      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "onwayrides-marketing-audience.csv";
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    });
  } catch (error) {
    showMarketingError(error.message ?? "Unable to export the marketing audience.");
  }
}

authForm?.addEventListener("submit", (event) => handleAuth(event, "email"));
googleButton?.addEventListener("click", (event) => handleAuth(event, "google"));
filterForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  loadAudience();
});
exportButton?.addEventListener("click", exportAudience);
signoutButton?.addEventListener("click", async () => {
  await signOut(auth);
  setScreen("auth");
});

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    setScreen("auth");
    return;
  }

  try {
    await syncAdmin();
    await loadAudience();
  } catch (error) {
    showAuthError(error.message ?? "Unable to verify admin access.");
    setScreen("auth");
  }
});
