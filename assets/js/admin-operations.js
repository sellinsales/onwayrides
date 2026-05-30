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
const dispatchFilterForm = document.querySelector("#ops-dispatch-filter-form");
const dispatchSummaryGrid = document.querySelector("#ops-dispatch-summary-grid");
const dispatchTableBody = document.querySelector("#ops-dispatch-table-body");
const dispatchError = document.querySelector("#ops-dispatch-error");
const roleManagementCard = document.querySelector("#ops-role-management-card");
const roleSearchForm = document.querySelector("#ops-role-search-form");
const roleSearchInput = document.querySelector("#ops-role-search");
const roleNoteInput = document.querySelector("#ops-role-note");
const rolePrimaryAdminPill = document.querySelector("#ops-primary-admin-pill");
const roleTableBody = document.querySelector("#ops-role-table-body");
const roleError = document.querySelector("#ops-role-error");
const roleSuccess = document.querySelector("#ops-role-success");
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
let currentViewer = null;
let roleManagementConfig = null;
let manageableRoles = ["rider", "support", "admin"];
let dispatchConfig = null;

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

function showDispatchError(message) {
  dispatchError.hidden = !message;
  dispatchError.textContent = message ?? "";
}

function showRoleError(message) {
  roleError.hidden = !message;
  roleError.textContent = message ?? "";
}

function showRoleSuccess(message) {
  roleSuccess.hidden = !message;
  roleSuccess.textContent = message ?? "";
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
    case "completed":
      return "good";
    case "accepted":
    case "arriving":
    case "in_progress":
      return "good";
    case "rejected":
    case "suspended":
    case "cancelled":
      return "warn";
    case "pending":
    case "searching":
    case "offered":
    case "scheduled":
      return "dark";
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

function renderRoleManagement(payload = {}) {
  currentViewer = payload.viewer ?? currentViewer;
  roleManagementConfig = payload.role_management ?? roleManagementConfig;

  const enabled = Boolean(payload.viewer?.can_manage_admins && payload.role_management?.enabled);
  roleManagementCard.hidden = !enabled;

  if (!enabled) {
    showRoleError("");
    showRoleSuccess("");
    roleTableBody.innerHTML = `
      <tr>
        <td colspan="4" class="helper-text">Only the primary admin can manage admin access.</td>
      </tr>
    `;
    return;
  }

  rolePrimaryAdminPill.textContent = `Primary admin: ${payload.role_management?.primary_admin_email ?? "akeelpmajk@gmail.com"}`;
}

function renderRoleRows(rows = []) {
  if (!rows.length) {
    roleTableBody.innerHTML = `
      <tr>
        <td colspan="4" class="helper-text">No users matched this search.</td>
      </tr>
    `;
    return;
  }

  roleTableBody.innerHTML = rows.map((user) => {
    const options = manageableRoles.map((role) => `
      <option value="${role}" ${user.role === role ? "selected" : ""}>${role}</option>
    `).join("");

    const helper = user.is_primary_admin
      ? "Primary admin account"
      : user.can_promote_to_admin
        ? `${user.status} | last login ${user.last_login_at ? new Date(user.last_login_at).toLocaleString() : "never"}`
        : "Operational account: use a separate admin email instead of replacing this role.";

    return `
      <tr>
        <td>
          <strong>${user.full_name ?? "OnWay User"}</strong><br>
          <span class="helper-text">${user.email ?? "No email"}${user.phone ? ` | ${user.phone}` : ""}</span>
        </td>
        <td>
          <strong>${user.role}</strong><br>
          <span class="helper-text">${helper}</span>
        </td>
        <td>
          <select data-role-select="${user.id}" ${user.is_primary_admin ? "disabled" : ""}>
            ${options}
          </select>
        </td>
        <td>
          <button class="primary-button" type="button" data-role-update="${user.id}" ${user.is_primary_admin ? "disabled" : ""}>Save access</button>
        </td>
      </tr>
    `;
  }).join("");

  roleTableBody.querySelectorAll("[data-role-update]").forEach((button) => {
    button.addEventListener("click", () => {
      const userId = button.getAttribute("data-role-update");
      const select = roleTableBody.querySelector(`[data-role-select="${userId}"]`);
      updateUserRole(userId, select?.value ?? "rider");
    });
  });
}

function buildDispatchParams() {
  const formData = new FormData(dispatchFilterForm);
  const params = new URLSearchParams();

  for (const [key, value] of formData.entries()) {
    if (String(value).trim()) {
      params.set(key, String(value).trim());
    }
  }

  return params;
}

function renderDispatchSummary(summary = {}) {
  const cards = [
    ["Unassigned", summary.open_unassigned ?? 0],
    ["Active trips", summary.active_trips ?? 0],
    ["Scheduled", summary.scheduled ?? 0],
    ["Completed today", summary.completed_today ?? 0],
    ["Online drivers", summary.online_drivers ?? 0],
    ["Busy drivers", summary.busy_drivers ?? 0],
  ];

  dispatchSummaryGrid.innerHTML = cards.map(([label, value]) => `
    <article>
      <strong>${value}</strong>
      <span>${label}</span>
    </article>
  `).join("");
}

function renderDispatchRows(rows = []) {
  if (!rows.length) {
    dispatchTableBody.innerHTML = `
      <tr>
        <td colspan="5" class="helper-text">No dispatch rows matched the current filter.</td>
      </tr>
    `;
    return;
  }

  dispatchTableBody.innerHTML = rows.map((row) => `
    <tr>
      <td>
        <strong>${row.reference}</strong><br>
        <span class="helper-text">${row.rider_name ?? "Rider"} | ${row.service_name ?? "Service"}</span>
      </td>
      <td>
        <strong>${row.pickup_address}</strong><br>
        <span class="helper-text">${row.destination_address}</span>
      </td>
      <td>
        <span class="pill ${row.needs_attention ? "warn" : badgeClassForStatus(row.status)}">${row.status_label}</span><br>
        <span class="helper-text">${row.fare_label} | ${row.payment_method}</span>
      </td>
      <td><span class="helper-text">${row.driver_name ?? "Unassigned"}</span></td>
      <td><span class="helper-text">${row.queue_age_minutes} min</span></td>
    </tr>
  `).join("");
}

async function loadDispatchBoard() {
  showDispatchError("");

  try {
    const payload = await withIdToken(async (idToken) => {
      const endpoint = dispatchConfig?.endpoint ?? "/admin/bookings/dispatch";
      const response = await fetch(buildApiUrl(endpoint.replace(/^\/api/, ""), buildDispatchParams()), {
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? "Unable to load the dispatch board.");
      }

      return data;
    });

    renderDispatchSummary(payload.summary);
    renderDispatchRows(payload.data);
  } catch (error) {
    showDispatchError(error.message ?? "Unable to load the dispatch board.");
  }
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

    renderRoleManagement(payload);
    dispatchConfig = payload.dispatch ?? dispatchConfig;
    renderSummary(payload.summary);
    renderRows(payload.data);
    setScreen("dashboard");

    await loadDispatchBoard();

    if (payload.viewer?.can_manage_admins && payload.role_management?.enabled) {
      await loadRoleCandidates();
    }
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

async function loadRoleCandidates() {
  if (!currentViewer?.can_manage_admins) {
    return;
  }

  showRoleError("");
  showRoleSuccess("");

  const params = new URLSearchParams();
  const search = roleSearchInput?.value.trim() ?? "";

  if (search) {
    params.set("q", search);
  }

  try {
    const payload = await withIdToken(async (idToken) => {
      const endpoint = roleManagementConfig?.users_endpoint ?? "/admin/users";
      const response = await fetch(buildApiUrl(endpoint.replace(/^\/api/, ""), params), {
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? "Unable to load admin access users.");
      }

      return data;
    });

    manageableRoles = payload.available_roles ?? manageableRoles;
    renderRoleRows(payload.data ?? []);
  } catch (error) {
    showRoleError(error.message ?? "Unable to load admin access users.");
  }
}

async function updateUserRole(userId, role) {
  showRoleError("");
  showRoleSuccess("");

  try {
    const payload = await withIdToken(async (idToken) => {
      const response = await fetch(buildApiUrl(`/admin/users/${userId}/role`), {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({
          role,
          note: roleNoteInput?.value.trim() || undefined,
        }),
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.message ?? "Unable to update user access.");
      }

      return data;
    });

    showRoleSuccess(payload.message ?? "User access updated.");
    await loadRoleCandidates();
  } catch (error) {
    showRoleError(error.message ?? "Unable to update user access.");
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
dispatchFilterForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  loadDispatchBoard();
});
roleSearchForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  loadRoleCandidates();
});
signoutButton?.addEventListener("click", async () => {
  await signOut(auth);
  currentApplication = null;
  currentViewer = null;
  roleManagementConfig = null;
  dispatchConfig = null;
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
