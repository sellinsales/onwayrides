import {
  browserLocalPersistence,
  getAuth,
  onAuthStateChanged,
  setPersistence,
  signOut,
} from "https://www.gstatic.com/firebasejs/12.7.0/firebase-auth.js";
import { initializeApp } from "https://www.gstatic.com/firebasejs/12.7.0/firebase-app.js";

const config = window.ONWAYRIDES_WEB_CONFIG ?? {};
const app = initializeApp(config.firebase ?? {});
const auth = getAuth(app);
await setPersistence(auth, browserLocalPersistence);

const workspaceTitle = document.querySelector("#workspace-title");
const workspaceCopy = document.querySelector("#workspace-copy");
const workspaceStatusBanner = document.querySelector("#workspace-status-banner");
const workspaceSummaryGrid = document.querySelector("#workspace-summary-grid");
const workspaceSignoutButton = document.querySelector("#workspace-signout-button");

const rideForm = document.querySelector("#workspace-ride-form");
const driverForm = document.querySelector("#workspace-driver-form");
const fleetForm = document.querySelector("#workspace-fleet-form");
const rideFormSuccess = document.querySelector("#ride-form-success");
const driverFormSuccess = document.querySelector("#driver-form-success");
const fleetFormSuccess = document.querySelector("#fleet-form-success");

function buildApiUrl(path) {
  return `${String(config.apiBaseUrl ?? "").replace(/\/$/, "")}${path}`;
}

function getQueryMode() {
  return new URLSearchParams(window.location.search).get("mode") ?? "returning";
}

function workspaceMessage(mode) {
  if (mode === "new") {
    return {
      title: "Welcome to your OnWay Rides workspace",
      copy:
        "Your account setup is complete. From here you can request a beta ride, start driver onboarding, or register fleet interest without going back through login.",
      banner:
        "Your new account is active. Use the rider, driver, or fleet modules below depending on what you want to do next.",
    };
  }

  return {
    title: "Welcome back to OnWay Rides",
    copy:
      "Your web and mobile account stay synced here. Use this workspace to continue your rider journey or move into driver and fleet onboarding.",
    banner:
      "Your beta account is active. Pick the lane that matches your goal and continue with support-guided actions below.",
  };
}

async function withIdToken(callback) {
  const user = auth.currentUser;
  if (!user) {
    throw new Error("Sign in required.");
  }

  const idToken = await user.getIdToken(true);
  return callback(idToken);
}

async function syncLogin() {
  return withIdToken(async (idToken) => {
    const response = await fetch(buildApiUrl("/auth/login"), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({
        platform: "web",
        role: "rider",
      }),
    });

    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.message ?? "Unable to load the OnWay Rides workspace.");
    }

    return payload;
  });
}

function renderSummary(session) {
  const user = session.user ?? {};
  const consents = session.consents ?? {};
  const beta = session.beta ?? {};
  const cards = [
    ["Logged in as", user.email ?? "Email not set"],
    ["Phone status", user.phone_verified_at ? "Verified" : user.phone ? "Saved for beta" : "Missing"],
    ["Beta rides/day", String(beta.daily_rides_limit ?? 3)],
    ["WhatsApp updates", consents.whatsapp_marketing_opt_in ? "Opted in" : "Optional"],
  ];

  workspaceSummaryGrid.innerHTML = cards
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

function renderWorkspace(session) {
  const user = session.user ?? {};
  const mode = getQueryMode();
  const welcome = workspaceMessage(mode);
  const firstName = user.full_name?.trim()?.split(/\s+/)[0] ?? "there";

  workspaceTitle.textContent = `${welcome.title}, ${firstName}.`;
  workspaceCopy.textContent = welcome.copy;
  workspaceStatusBanner.querySelector("p").textContent = welcome.banner;
  renderSummary(session);
}

function buildMessageBlock(title, fields) {
  const lines = [title, ""];

  for (const [label, value] of fields) {
    lines.push(`${label}: ${value || "Not provided"}`);
  }

  return lines.join("\n");
}

function presentSupportMessage(successSlot, title, fields) {
  const message = buildMessageBlock(title, fields);
  const encoded = encodeURIComponent(message);
  const businessNumber = String(config.whatsappBusinessNumber ?? "").replace(/[^\d]/g, "");
  const whatsappUrl = businessNumber ? `https://wa.me/${businessNumber}?text=${encoded}` : null;
  const emailUrl = `mailto:${config.supportEmail ?? "support@onwayrides.com"}?subject=${encodeURIComponent(title)}&body=${encoded}`;

  successSlot.hidden = false;
  successSlot.innerHTML = whatsappUrl
    ? `Prepared your request. <a href="${whatsappUrl}" target="_blank" rel="noopener">Send it on WhatsApp</a> or <a href="${emailUrl}">email support</a>.`
    : `Prepared your request. <a href="${emailUrl}">Email support</a> to continue.`;
}

rideForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(rideForm);

  presentSupportMessage(rideFormSuccess, "OnWay Rides beta rider request", [
    ["City", data.get("city")],
    ["Service type", data.get("service_type")],
    ["Pickup area", data.get("pickup_area")],
    ["Destination area", data.get("destination_area")],
    ["Notes", data.get("notes")],
  ]);
});

driverForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(driverForm);

  presentSupportMessage(driverFormSuccess, "OnWay Rides driver application intent", [
    ["City", data.get("city")],
    ["Vehicle type", data.get("vehicle_type")],
    ["Availability", data.get("availability")],
    ["License status", data.get("license_status")],
    ["Notes", data.get("notes")],
  ]);
});

fleetForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(fleetForm);

  presentSupportMessage(fleetFormSuccess, "OnWay Rides fleet and business interest", [
    ["Company / fleet name", data.get("company_name")],
    ["Fleet size", data.get("fleet_size")],
    ["City", data.get("city")],
    ["Use case", data.get("use_case")],
    ["Notes", data.get("notes")],
  ]);
});

workspaceSignoutButton?.addEventListener("click", async () => {
  await signOut(auth);
  window.location.href = "login.html";
});

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    window.location.href = "login.html";
    return;
  }

  try {
    const session = await syncLogin();

    if (!session.requirements?.profile_complete) {
      window.location.href = "login.html";
      return;
    }

    renderWorkspace(session);
  } catch {
    window.location.href = "login.html";
  }
});
