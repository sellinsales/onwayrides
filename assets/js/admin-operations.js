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

const authScreen = document.querySelector("#ops-auth-screen");
const dashboardScreen = document.querySelector("#ops-dashboard-screen");
const authForm = document.querySelector("#ops-auth-form");
const authError = document.querySelector("#ops-auth-error");
const googleButton = document.querySelector("#ops-google-button");
const signoutButton = document.querySelector("#ops-signout-button");
const filterForm = document.querySelector("#ops-filter-form");
const summaryGrid = document.querySelector("#ops-summary-grid");
const tableBody = document.querySelector("#ops-table-body");
const tableError = document.querySelector("#ops-table-error");
const detailCard = document.querySelector("#ops-detail-card");
const detailTitle = document.querySelector("#ops-detail-title");
const detailSummary = document.querySelector("#ops-detail-summary");
const detailSuccess = document.querySelector("#ops-detail-success");
const detailError = document.querySelector("#ops-detail-error");
const driverProfileCopy = document.querySelector("#ops-driver-profile-copy");
const driverVehicleCopy = document.querySelector("#ops-driver-vehicle-copy");
const documentsList = document.querySelector("#ops-documents-list");
const approvalIssues = document.querySelector("#ops-approval-issues");
const driverNotes = document.querySelector("#ops-driver-notes");
const approveDriverButton = document.querySelector("#ops-approve-driver-button");
const rejectDriverButton = document.querySelector("#ops-reject-driver-button");
const reopenDriverButton = document.querySelector("#ops-reopen-driver-button");
const suspendDriverButton = document.querySelector("#ops-suspend-driver-button");

let currentApplication = null;

function buildApiUrl(path, params = new URLSearchParams()) {
  const apiBaseUrl = String(config.apiBaseUrl ?? `${window.location.origin}/api`).replace(/\/$/, "");
  const base = `${apiBaseUrl}${path}`;
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

function setScreen(screen) {
  authScreen.hidden = screen !== "auth";
  dashboardScreen.hidden = screen !== "dashboard";
}

function showAuthError(message) {
  authError.hidden = !message;
  authError.textContent = message ?? "";
}

function showTableError(message) {
  tableError.hidden = !message;
  tableError.textContent = message ?? "";
}

function showDetailError(message) {
  detailError.hidden = !message;
  detailError.textContent = message ?? "";
}

function showDetailSuccess(message) {
  detailSuccess.hidden = !message;
  detailSuccess.textContent = message ?? "";
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
      throw new Error("This account is not allowed to access driver operations.");
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
    ["Pending review", summary.pending_review ?? 0],
    ["Approved", summary.approved ?? 0],
    ["Rejected", summary.rejected ?? 0],
    ["Suspended", summary.suspended ?? 0],
  ];

  summaryGrid.innerHTML = cards.map(([label, value]) => `
    <article>
      <strong>${value}</strong>
      <span>${label}</span>
    </article>
  `).join("");
}

function badgeClassForStatus(status) {
  switch (status) {
    case "approved":
      return "good";
    case "rejected":
    case "suspended":
      return "warn";
    default:
      return "dark";
  }
}

function renderRows(rows = []) {
  tableBody.innerHTML = rows.map((row) => `
    <tr>
      <td>
        <strong>${row.full_name ?? "Driver"}</strong><br>
        <span class="helper-text">${row.email ?? "No email"} | ${row.driver_code ?? "No code"}</span>
      </td>
      <td><span class="helper-text">${row.city_name ?? "Unassigned city"}</span></td>
      <td>
        <strong>${row.document_summary.approved}/${row.document_summary.total}</strong><br>
        <span class="helper-text">Pending ${row.document_summary.pending}, Rejected ${row.document_summary.rejected}</span>
      </td>
      <td><span class="helper-text">${(row.service_types ?? []).join(", ") || "No services"}</span></td>
      <td><span class="pill ${badgeClassForStatus(row.onboarding_status)}">${row.status_label}</span></td>
      <td><button class="ghost-button" type="button" data-driver-id="${row.id}">Review</button></td>
    </tr>
  `).join("");

  tableBody.querySelectorAll("[data-driver-id]").forEach((button) => {
    button.addEventListener("click", () => {
      loadApplicationDetail(button.getAttribute("data-driver-id"));
    });
  });
}

async function loadQueue() {
  showTableError("");

  try {
    const payload = await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl("/admin/drivers/applications", buildParams()), {
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? "Unable to load the driver queue.");
      }

      return data;
    });

    renderSummary(payload.summary);
    renderRows(payload.data);
    setScreen("dashboard");
  } catch (error) {
    showTableError(error.message ?? "Unable to load the driver queue.");
  }
}

async function loadApplicationDetail(driverProfileId) {
  showDetailError("");
  showDetailSuccess("");

  try {
    const payload = await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl(`/admin/drivers/applications/${driverProfileId}`), {
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? "Unable to load the driver application.");
      }

      return data;
    });

    currentApplication = payload.application;
    renderApplicationDetail(payload.application);
  } catch (error) {
    showDetailError(error.message ?? "Unable to load the driver application.");
  }
}

function renderApplicationDetail(application) {
  detailCard.hidden = false;
  detailTitle.textContent = `${application.user.full_name} | ${application.driver_code ?? "No code"}`;

  detailSummary.innerHTML = [
    ["Onboarding", application.status_label],
    ["Phone", application.user.phone ?? "Not set"],
    ["City", application.city?.name ?? "Not assigned"],
    ["Services", (application.services ?? []).filter((service) => service.is_enabled).length],
  ].map(([label, value]) => `
    <article>
      <strong>${value}</strong>
      <span>${label}</span>
    </article>
  `).join("");

  driverProfileCopy.innerHTML = `
    <strong>${application.user.full_name}</strong><br>
    <span class="helper-text">${application.user.email ?? "No email"}</span><br>
    <span class="helper-text">License: ${application.license_number ?? "Pending"}</span><br>
    <span class="helper-text">CNIC: ${application.user.national_id_number ?? "Pending"}</span><br>
    <span class="helper-text">Trips completed: ${application.trips_completed}</span>
  `;

  if (application.vehicle) {
    driverVehicleCopy.innerHTML = `
      <strong>${application.vehicle.label || "Assigned vehicle"}</strong><br>
      <span class="helper-text">Plate: ${application.vehicle.plate_number ?? "Pending"}</span><br>
      <span class="helper-text">Status: ${application.vehicle.status}</span><br>
      <span class="helper-text">Fuel: ${application.vehicle.fuel_type ?? "Unknown"} | Seats: ${application.vehicle.seats ?? "Unknown"}</span>
    `;
  } else {
    driverVehicleCopy.textContent = "No current vehicle assignment.";
  }

  if (application.approval_issues?.length) {
    approvalIssues.hidden = false;
    approvalIssues.innerHTML = `
      <strong>Approval blocked</strong>
      <p>${application.approval_issues.join(" ")}</p>
    `;
  } else {
    approvalIssues.hidden = true;
    approvalIssues.innerHTML = "";
  }

  driverNotes.textContent = application.notes?.trim() || "No admin notes yet.";

  documentsList.innerHTML = (application.documents ?? []).map((document) => `
    <article class="workspace-card" data-document-id="${document.id}">
      <span class="material-symbols-outlined">description</span>
      <h3>${document.document_label}</h3>
      <div class="helper-text">
        Status: ${document.status}<br>
        Number: ${document.document_number ?? "Not provided"}<br>
        Reviewed by: ${document.reviewed_by_email ?? "Not reviewed"}<br>
        Reviewed at: ${document.reviewed_at ?? "Not reviewed"}<br>
        ${document.rejection_reason ? `Reason: ${document.rejection_reason}` : ""}
      </div>
      <div class="inline-actions" style="margin-top:14px; flex-wrap:wrap;">
        <button class="ghost-button" type="button" data-preview-id="${document.id}">Open file</button>
        <button class="primary-button" type="button" data-approve-document="${document.id}">Approve</button>
        <button class="outline-button" type="button" data-reject-document="${document.id}">Reject</button>
      </div>
    </article>
  `).join("") || '<div class="helper-text">No driver documents uploaded yet.</div>';

  documentsList.querySelectorAll("[data-preview-id]").forEach((button) => {
    button.addEventListener("click", () => {
      const document = application.documents.find((item) => String(item.id) === button.getAttribute("data-preview-id"));
      if (document?.preview_endpoint) {
        openDocumentPreview(document.preview_endpoint);
      }
    });
  });

  documentsList.querySelectorAll("[data-approve-document]").forEach((button) => {
    button.addEventListener("click", () => {
      updateDocumentStatus(button.getAttribute("data-approve-document"), "approved");
    });
  });

  documentsList.querySelectorAll("[data-reject-document]").forEach((button) => {
    button.addEventListener("click", () => {
      const reason = window.prompt("Enter the rejection reason for this document:");
      if (!reason || !reason.trim()) {
        return;
      }
      updateDocumentStatus(button.getAttribute("data-reject-document"), "rejected", reason.trim());
    });
  });

  approveDriverButton.onclick = () => updateDriverStatus("approve");
  rejectDriverButton.onclick = () => {
    const note = window.prompt("Enter the rejection note for this driver application:");
    if (!note || !note.trim()) {
      return;
    }
    updateDriverStatus("reject", note.trim());
  };
  reopenDriverButton.onclick = () => updateDriverStatus("reopen");
  suspendDriverButton.onclick = () => {
    const note = window.prompt("Optional suspension note:");
    updateDriverStatus("suspend", note?.trim() || "");
  };
}

async function openDocumentPreview(previewEndpoint) {
  showDetailError("");

  try {
    await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl(previewEndpoint.replace(/^\/api/, "")), {
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });

      if (!response.ok) {
        throw new Error("Unable to open the secure document file.");
      }

      const blob = await response.blob();
      const blobUrl = URL.createObjectURL(blob);
      window.open(blobUrl, "_blank", "noopener");
      window.setTimeout(() => URL.revokeObjectURL(blobUrl), 60_000);
    });
  } catch (error) {
    showDetailError(error.message ?? "Unable to open the secure document file.");
  }
}

async function updateDocumentStatus(documentId, status, rejectionReason = "") {
  showDetailError("");
  showDetailSuccess("");

  try {
    const payload = await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl(`/admin/driver-documents/${documentId}/status`), {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          status,
          rejection_reason: rejectionReason || undefined,
        }),
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? "Unable to update the document review.");
      }

      return data;
    });

    currentApplication = payload.application;
    renderApplicationDetail(payload.application);
    showDetailSuccess(payload.message ?? "Driver document updated.");
    await loadQueue();
  } catch (error) {
    showDetailError(error.message ?? "Unable to update the document review.");
  }
}

async function updateDriverStatus(decision, note = "") {
  if (!currentApplication?.id) {
    return;
  }

  showDetailError("");
  showDetailSuccess("");

  try {
    const payload = await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl(`/admin/drivers/applications/${currentApplication.id}/status`), {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          decision,
          note: note || undefined,
        }),
      });

      const data = await response.json();
      if (!response.ok) {
        const issueMessage = Array.isArray(data.issues) && data.issues.length
          ? `${data.message} ${data.issues.join(" ")}`
          : data.message;
        throw new Error(issueMessage ?? "Unable to update the driver application.");
      }

      return data;
    });

    currentApplication = payload.application;
    renderApplicationDetail(payload.application);
    showDetailSuccess(payload.message ?? "Driver application updated.");
    await loadQueue();
  } catch (error) {
    showDetailError(error.message ?? "Unable to update the driver application.");
  }
}

async function handleAuth(event, mode = "email") {
  event.preventDefault();
  showAuthError("");

  try {
    if (mode === "google") {
      await signInWithPopup(auth, new GoogleAuthProvider());
    } else {
      const email = document.querySelector("#ops-email").value.trim();
      const password = document.querySelector("#ops-password").value;
      await signInWithEmailAndPassword(auth, email, password);
    }

    await syncAdmin();
    await loadQueue();
  } catch (error) {
    showAuthError(error.message ?? "Unable to sign in.");
    setScreen("auth");
  }
}

authForm?.addEventListener("submit", (event) => handleAuth(event, "email"));
googleButton?.addEventListener("click", (event) => handleAuth(event, "google"));
filterForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  loadQueue();
});
signoutButton?.addEventListener("click", async () => {
  await signOut(auth);
  currentApplication = null;
  detailCard.hidden = true;
  setScreen("auth");
});

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    setScreen("auth");
    return;
  }

  try {
    await syncAdmin();
    await loadQueue();
  } catch (error) {
    showAuthError(error.message ?? "Unable to verify admin access.");
    setScreen("auth");
  }
});
