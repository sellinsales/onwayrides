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
const workspaceAdminBanner = document.querySelector("#workspace-admin-banner");
const workspaceSummaryGrid = document.querySelector("#workspace-summary-grid");
const workspaceJourneyGrid = document.querySelector("#workspace-journey-grid");
const workspaceSignoutButton = document.querySelector("#workspace-signout-button");
const workspaceAdminNavLink = document.querySelector("#workspace-admin-nav-link");
const workspaceAdminShortcut = document.querySelector("#workspace-admin-shortcut");
const workspaceAdminCard = document.querySelector("#workspace-admin-card");

const rideForm = document.querySelector("#workspace-ride-form");
const driverForm = document.querySelector("#workspace-driver-form");
const fleetForm = document.querySelector("#workspace-fleet-form");
const driverDocumentForm = document.querySelector("#driver-document-form");

const rideFormSuccess = document.querySelector("#ride-form-success");
const driverFormSuccess = document.querySelector("#driver-form-success");
const fleetFormSuccess = document.querySelector("#fleet-form-success");
const driverDocumentSuccess = document.querySelector("#driver-document-success");
const driverDocumentSummary = document.querySelector("#driver-document-summary");
const driverDocumentLockedBanner = document.querySelector("#driver-document-locked-banner");

const rideCity = document.querySelector("#ride-city");
const rideService = document.querySelector("#ride-service");
const driverCity = document.querySelector("#driver-city");
const fleetCity = document.querySelector("#fleet-city");
const driverServiceTypes = document.querySelector("#driver-service-types");
const driverVehicleCategory = document.querySelector("#driver-vehicle-category");
const driverVehicleType = document.querySelector("#driver-vehicle-type");
const driverVehicleMake = document.querySelector("#driver-vehicle-make");
const driverVehicleModel = document.querySelector("#driver-vehicle-model");
const driverDocumentType = document.querySelector("#driver-document-type");
const driverDocumentHelp = document.querySelector("#driver-document-help");

let lastSession = null;
let referenceData = null;

function buildApiUrl(path) {
  return `${String(config.apiBaseUrl ?? "").replace(/\/$/, "")}${path}`;
}

function getQueryMode() {
  return new URLSearchParams(window.location.search).get("mode") ?? "returning";
}

function workspaceMessage(mode) {
  if (mode === "new") {
    return {
      title: "Welcome to your OnWay Rides hub",
      copy:
        "Your account setup is complete. From here you can request a ride, continue driver onboarding, or register a fleet account without signing in again.",
      banner:
        "Your account is active. Choose the path that matches your next trip, driver application, or business setup.",
    };
  }

  return {
    title: "Welcome back to OnWay Rides",
    copy:
      "Your web and mobile account stay connected here. Use this space to manage rider requests, driver onboarding, and fleet setup from one place.",
    banner:
      "Your account is ready. Continue with the guided steps below and your latest details stay saved for the next visit.",
  };
}

function userHasAdminAccess(user = {}) {
  return ["admin", "support"].includes(String(user?.role ?? ""));
}

function hasDriverDraft(workspace = {}) {
  const driver = workspace?.driver_application;

  return Boolean(driver && (driver.id || driver.city_id || driver.license_number));
}

function documentStatusSummary(documents = []) {
  const total = documents.length;
  const approved = documents.filter((document) => document.status === "approved").length;
  const pending = documents.filter((document) => document.status !== "approved").length;

  return { total, approved, pending };
}

function setFormEnabled(form, enabled) {
  if (!form) {
    return;
  }

  form.querySelectorAll("input, select, textarea, button").forEach((element) => {
    if (element.id === "driver-document-help") {
      element.disabled = true;
      return;
    }

    element.disabled = !enabled;
  });
}

function buildMessageBlock(title, fields) {
  const lines = [title, ""];

  for (const [label, value] of fields) {
    lines.push(`${label}: ${value || "Not provided"}`);
  }

  return lines.join("\n");
}

function successMarkup(message, href, label = "Open WhatsApp") {
  if (!href) {
    return message;
  }

  return `${message} <a href="${href}" target="_blank" rel="noopener">${label}</a>`;
}

function hideSuccess(slot) {
  if (!slot) {
    return;
  }

  slot.hidden = true;
  slot.innerHTML = "";
}

function showSuccess(slot, html) {
  if (!slot) {
    return;
  }

  slot.hidden = false;
  slot.innerHTML = html;
}

async function withIdToken(callback) {
  const user = auth.currentUser;
  if (!user) {
    throw new Error("Sign in required.");
  }

  const idToken = await user.getIdToken(true);
  return callback(idToken);
}

async function fetchJson(path, options = {}) {
  return withIdToken(async (idToken) => {
    const response = await fetch(buildApiUrl(path), {
      ...options,
      headers: {
        Authorization: `Bearer ${idToken}`,
        ...(options.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
        ...(options.headers ?? {}),
      },
    });

    const contentType = response.headers.get("content-type") ?? "";
    const payload = contentType.includes("application/json") ? await response.json() : {};

    if (!response.ok) {
      const firstError = payload?.errors
        ? Object.values(payload.errors).flat().find(Boolean)
        : null;

      throw new Error(firstError || payload.message || "Unable to complete this request.");
    }

    return payload;
  });
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

async function loadReferenceData() {
  const payload = await fetchJson("/onboarding/reference-data", { method: "GET" });
  referenceData = payload;
  return payload;
}

async function loadWorkspacePayload() {
  const payload = await fetchJson("/onboarding/workspace", { method: "GET" });
  return payload.workspace ?? {};
}

function clearSelect(select, placeholder, options, selectedValue = "") {
  select.innerHTML = "";

  const first = document.createElement("option");
  first.value = "";
  first.textContent = options.length ? placeholder : "No options loaded yet";
  first.disabled = !options.length;
  first.selected = !options.length || selectedValue === "";
  select.appendChild(first);

  options.forEach((option) => {
    const element = document.createElement("option");
    element.value = String(option.value);
    element.textContent = option.label;
    if (String(selectedValue) === String(option.value)) {
      element.selected = true;
    }
    select.appendChild(element);
  });
}

function renderCityOptions(selectedDriverCity = "", selectedFleetCity = "", selectedRideCity = "") {
  const cityOptions = (referenceData?.cities ?? []).map((city) => ({
    value: city.id,
    label: city.name,
  }));

  clearSelect(rideCity, "Choose rider city", cityOptions, selectedRideCity);
  clearSelect(driverCity, "Choose driver city", cityOptions, selectedDriverCity);
  clearSelect(fleetCity, "Choose fleet city", cityOptions, selectedFleetCity);
}

function renderRideServiceOptions() {
  const options = (referenceData?.service_types ?? []).map((serviceType) => ({
    value: serviceType.slug,
    label: serviceType.name,
  }));

  clearSelect(rideService, "Choose service type", options);
}

function renderDriverServiceCheckboxes(selectedIds = []) {
  const selected = new Set((selectedIds ?? []).map((id) => String(id)));

  if (!(referenceData?.service_types ?? []).length) {
    driverServiceTypes.innerHTML = `
      <div class="helper-text">Service types are not available right now. Please try again shortly.</div>
    `;
    return;
  }

  driverServiceTypes.innerHTML = (referenceData?.service_types ?? [])
    .map(
      (serviceType) => `
        <label class="checkbox-item">
          <input type="checkbox" name="service_type_ids" value="${serviceType.id}" ${selected.has(String(serviceType.id)) ? "checked" : ""}>
          <span>${serviceType.name}</span>
        </label>
      `,
    )
    .join("");
}

function renderVehicleCategoryOptions(selectedValue = "") {
  const options = (referenceData?.vehicle_categories ?? []).map((category) => ({
    value: category.id,
    label: category.name,
  }));

  clearSelect(driverVehicleCategory, "Choose category", options, selectedValue);
}

function renderVehicleTypeOptions(selectedValue = "") {
  const currentCategory = String(driverVehicleCategory.value || "");
  const options = (referenceData?.vehicle_types ?? [])
    .filter((type) => !currentCategory || String(type.vehicle_category_id) === currentCategory)
    .map((type) => ({
      value: type.id,
      label: `${type.name}${type.seats ? ` (${type.seats} seats)` : ""}`,
    }));

  clearSelect(driverVehicleType, "Choose vehicle type", options, selectedValue);
}

function renderVehicleMakeOptions(selectedValue = "") {
  const options = (referenceData?.vehicle_makes ?? []).map((make) => ({
    value: make.id,
    label: make.name,
  }));

  clearSelect(driverVehicleMake, "Choose make", options, selectedValue);
}

function renderVehicleModelOptions(selectedValue = "") {
  const currentMake = String(driverVehicleMake.value || "");
  const options = (referenceData?.vehicle_models ?? [])
    .filter((model) => !currentMake || String(model.vehicle_make_id) === currentMake)
    .map((model) => ({
      value: model.id,
      label: model.name,
    }));

  clearSelect(driverVehicleModel, "Choose model", options, selectedValue);
}

function renderDocumentTypeOptions(selectedValue = "") {
  const options = (referenceData?.driver_document_types ?? []).map((documentType) => ({
    value: documentType.value,
    label: documentType.label,
  }));

  clearSelect(driverDocumentType, "Choose document type", options, selectedValue);
  updateDocumentHelp();
}

function updateDocumentHelp() {
  const key = driverDocumentType.value;
  const samples = referenceData?.driver_samples ?? {};
  driverDocumentHelp.value = samples[key] ?? "Select a document type to see the upload guidance.";
}

function renderSummary(session, workspace) {
  const user = session.user ?? {};
  const consents = session.consents ?? {};
  const driver = workspace?.driver_application;
  const fleet = workspace?.fleet_application;
  const documents = workspace?.driver_application?.documents ?? [];
  const documentSummary = documentStatusSummary(documents);
  const cards = [
    ["Logged in as", user.email ?? "Email not set"],
    ["Phone status", user.phone_verified_at ? "Verified" : user.phone ? "Saved" : "Missing"],
    ["Driver draft", driver ? driver.onboarding_status ?? driver.status ?? "In progress" : "Not started"],
    ["Driver documents", documents.length ? `${documentSummary.approved}/${documentSummary.total} reviewed` : "Not uploaded"],
    ["Fleet draft", fleet ? fleet.status ?? "Pending" : "Not started"],
    ["WhatsApp updates", consents.whatsapp_marketing_opt_in ? "Opted in" : "Optional"],
    ["SMS updates", consents.sms_marketing_opt_in ? "Opted in" : "Optional"],
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

function renderWorkspace(session, workspace) {
  const user = session.user ?? {};
  const mode = getQueryMode();
  const welcome = workspaceMessage(mode);
  const firstName = user.full_name?.trim()?.split(/\s+/)[0] ?? "there";

  workspaceTitle.textContent = `${welcome.title}, ${firstName}.`;
  workspaceCopy.textContent = welcome.copy;
  workspaceStatusBanner.querySelector("p").textContent = welcome.banner;
  renderAdminAccess(session);
  renderSummary(session, workspace);
  renderJourney(session, workspace);
}

function renderAdminAccess(session) {
  const user = session?.user ?? {};
  const hasAccess = userHasAdminAccess(user);

  workspaceAdminNavLink?.toggleAttribute("hidden", !hasAccess);
  workspaceAdminShortcut?.toggleAttribute("hidden", !hasAccess);
  workspaceAdminCard?.toggleAttribute("hidden", !hasAccess);
  workspaceAdminBanner?.toggleAttribute("hidden", !hasAccess);

  if (!hasAccess || !workspaceAdminBanner) {
    return;
  }

  const roleLabel = String(user.role ?? "admin");
  workspaceAdminBanner.querySelector("p").textContent = roleLabel === "support"
    ? "This support account can open the operations panel to review onboarding and service activity."
    : "This admin account can open the operations panel to review onboarding, service activity, and protected tools.";
}

function renderJourney(session, workspace) {
  if (!workspaceJourneyGrid) {
    return;
  }

  const user = session?.user ?? {};
  const driverDraft = hasDriverDraft(workspace);
  const documents = workspace?.driver_application?.documents ?? [];
  const documentSummary = documentStatusSummary(documents);
  const fleet = workspace?.fleet_application;

  const steps = [
    {
      title: "Account ready",
      value: user.phone ? "Complete" : "Needs phone",
      copy: user.phone
        ? "Your account can be used across web and mobile."
        : "Add your contact details to keep ride and support updates accurate.",
    },
    {
      title: "Rider request",
      value: "Available now",
      copy: "You can share pickup, destination, schedule, and trip notes anytime.",
    },
    {
      title: "Driver application",
      value: driverDraft ? "Saved" : "Start here",
      copy: driverDraft
        ? "Your driver application is saved. Continue with document upload below."
        : "Complete your city, services, and vehicle details first.",
    },
    {
      title: "Driver documents",
      value: documents.length ? `${documentSummary.approved}/${documentSummary.total}` : "Waiting",
      copy: documents.length
        ? "Keep uploading or reviewing required documents until everything is approved."
        : "Document upload opens after you save the driver application.",
    },
    {
      title: "Fleet setup",
      value: fleet ? "Saved" : "Optional",
      copy: fleet
        ? "Your business or fleet enquiry is saved for follow-up."
        : "Use this if you manage multiple vehicles or company transport.",
    },
  ];

  workspaceJourneyGrid.innerHTML = steps.map((step) => `
    <article>
      <strong>${step.value}</strong>
      <span>${step.title}</span>
      <div class="helper-text" style="margin-top:8px;">${step.copy}</div>
    </article>
  `).join("");
}

function renderDriverDocumentState(workspace) {
  const unlocked = hasDriverDraft(workspace);

  driverDocumentLockedBanner?.toggleAttribute("hidden", unlocked);
  setFormEnabled(driverDocumentForm, unlocked);
}

function prefillDriverForm(workspace) {
  const driver = workspace?.driver_application;
  if (!driver) {
    renderDriverServiceCheckboxes([]);
    return;
  }

  driverCity.value = driver.city_id ? String(driver.city_id) : "";
  document.querySelector("#driver-license-number").value = driver.license_number ?? "";
  document.querySelector("#driver-national-id").value = workspace?.user?.national_id_number ?? "";
  document.querySelector("#driver-notes").value = driver.notes ?? "";
  renderDriverServiceCheckboxes(driver.service_type_ids ?? []);

  const vehicle = driver.vehicle ?? {};
  driverVehicleCategory.value = vehicle.vehicle_category_id ? String(vehicle.vehicle_category_id) : "";
  renderVehicleTypeOptions(vehicle.vehicle_type_id ? String(vehicle.vehicle_type_id) : "");
  renderVehicleMakeOptions(vehicle.vehicle_make_id ? String(vehicle.vehicle_make_id) : "");
  renderVehicleModelOptions(vehicle.vehicle_model_id ? String(vehicle.vehicle_model_id) : "");
  document.querySelector("#driver-plate-number").value = vehicle.plate_number ?? "";
  document.querySelector("#driver-year").value = vehicle.year_of_manufacture ?? "";
  document.querySelector("#driver-seats").value = vehicle.seats ?? "";
  document.querySelector("#driver-fuel-type").value = vehicle.fuel_type ?? "";
}

function prefillFleetForm(session, workspace) {
  const fleet = workspace?.fleet_application;

  if (!fleet) {
    document.querySelector("#fleet-support-phone").value = session.user?.phone ?? "";
    document.querySelector("#fleet-support-email").value = session.user?.email ?? "";
    return;
  }

  fleetCity.value = fleet.city_id ? String(fleet.city_id) : "";
  document.querySelector("#fleet-company").value = fleet.company_name ?? "";
  document.querySelector("#fleet-size").value = workspace?.metadata?.fleet_onboarding?.fleet_size ?? "";
  document.querySelector("#fleet-model").value = workspace?.metadata?.fleet_onboarding?.use_case ?? "";
  document.querySelector("#fleet-business-model").value = fleet.business_model ?? "commission";
  document.querySelector("#fleet-support-phone").value = fleet.support_phone ?? session.user?.phone ?? "";
  document.querySelector("#fleet-support-email").value = fleet.support_email ?? session.user?.email ?? "";
  document.querySelector("#fleet-notes").value = fleet.notes ?? "";
}

function renderDriverDocuments(workspace) {
  const documents = workspace?.driver_application?.documents ?? [];

  if (!documents.length) {
    driverDocumentSummary.innerHTML = `
      <article>
        <strong>No driver documents uploaded yet</strong>
        <span>Upload your selfie, license, CNIC, and vehicle files one at a time.</span>
      </article>
    `;
    renderDriverDocumentState(workspace);
    return;
  }

  driverDocumentSummary.innerHTML = documents
    .map(
      (document) => `
        <article>
          <strong>${document.document_type.replaceAll("_", " ")}</strong>
          <span>Status: ${document.status}</span>
        </article>
      `,
    )
    .join("");

  renderDriverDocumentState(workspace);
}

function populateReferenceDrivenFields(session, workspace) {
  renderCityOptions(
    workspace?.driver_application?.city_id ?? "",
    workspace?.fleet_application?.city_id ?? "",
    "",
  );
  renderRideServiceOptions();
  renderVehicleCategoryOptions(workspace?.driver_application?.vehicle?.vehicle_category_id ?? "");
  renderVehicleTypeOptions(workspace?.driver_application?.vehicle?.vehicle_type_id ?? "");
  renderVehicleMakeOptions(workspace?.driver_application?.vehicle?.vehicle_make_id ?? "");
  renderVehicleModelOptions(workspace?.driver_application?.vehicle?.vehicle_model_id ?? "");
  renderDocumentTypeOptions();
  prefillDriverForm(workspace);
  prefillFleetForm(session, workspace);
  renderDriverDocuments(workspace);
}

function referencesAreSeeded() {
  return Boolean(
    (referenceData?.cities ?? []).length &&
    (referenceData?.service_types ?? []).length &&
    (referenceData?.vehicle_categories ?? []).length,
  );
}

function buildSupportMessage(title, fields) {
  const message = buildMessageBlock(title, fields);
  const encoded = encodeURIComponent(message);
  const businessNumber = String(config.whatsappBusinessNumber ?? "").replace(/[^\d]/g, "");
  const whatsappUrl = businessNumber ? `https://wa.me/${businessNumber}?text=${encoded}` : null;

  return {
    message,
    whatsappUrl,
  };
}

rideForm?.addEventListener("submit", (event) => {
  event.preventDefault();
  hideSuccess(rideFormSuccess);

  const data = new FormData(rideForm);
  const support = buildSupportMessage("OnWay Rides rider request", [
    ["City", rideCity.options[rideCity.selectedIndex]?.textContent ?? ""],
    ["Service type", rideService.options[rideService.selectedIndex]?.textContent ?? ""],
    ["Pickup area", data.get("pickup_area")],
    ["Destination area", data.get("destination_area")],
    ["Timing", data.get("timing")],
    ["Vehicle preference", data.get("vehicle_preference")],
    ["Notes", data.get("notes")],
  ]);

  showSuccess(
    rideFormSuccess,
    successMarkup(
      "Your trip details are ready to send.",
      support.whatsappUrl,
      "Continue on WhatsApp",
    ),
  );
});

driverVehicleCategory?.addEventListener("change", () => {
  renderVehicleTypeOptions();
});

driverVehicleMake?.addEventListener("change", () => {
  renderVehicleModelOptions();
});

driverDocumentType?.addEventListener("change", updateDocumentHelp);

driverForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  hideSuccess(driverFormSuccess);

  const checkedServices = [...driverServiceTypes.querySelectorAll('input[name="service_type_ids"]:checked')].map(
    (input) => Number(input.value),
  );

  if (!checkedServices.length) {
    showSuccess(driverFormSuccess, "Choose at least one driver service type before saving.");
    return;
  }

  const payload = {
    city_id: Number(driverCity.value),
    license_number: document.querySelector("#driver-license-number").value.trim(),
    national_id_number: document.querySelector("#driver-national-id").value.trim(),
    vehicle_category_id: driverVehicleCategory.value ? Number(driverVehicleCategory.value) : null,
    vehicle_type_id: driverVehicleType.value ? Number(driverVehicleType.value) : null,
    vehicle_make_id: driverVehicleMake.value ? Number(driverVehicleMake.value) : null,
    vehicle_model_id: driverVehicleModel.value ? Number(driverVehicleModel.value) : null,
    vehicle_make_other: document.querySelector("#driver-vehicle-make-other").value.trim() || null,
    vehicle_model_other: document.querySelector("#driver-vehicle-model-other").value.trim() || null,
    plate_number: document.querySelector("#driver-plate-number").value.trim() || null,
    year_of_manufacture: document.querySelector("#driver-year").value ? Number(document.querySelector("#driver-year").value) : null,
    seats: document.querySelector("#driver-seats").value ? Number(document.querySelector("#driver-seats").value) : null,
    fuel_type: document.querySelector("#driver-fuel-type").value || null,
    service_type_ids: checkedServices,
    availability: document.querySelector("#driver-availability").value,
    license_status: document.querySelector("#driver-license").value,
    notes: document.querySelector("#driver-notes").value.trim() || null,
  };

  try {
    const response = await fetchJson("/onboarding/driver", {
      method: "PATCH",
      body: JSON.stringify(payload),
    });
    renderWorkspace(lastSession, response.workspace);
    renderDriverDocuments(response.workspace);
    showSuccess(driverFormSuccess, "Driver application saved. You can continue with document upload now.");
  } catch (error) {
    showSuccess(driverFormSuccess, error.message);
  }
});

driverDocumentForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  hideSuccess(driverDocumentSuccess);

  const formData = new FormData(driverDocumentForm);

  try {
    await fetchJson("/onboarding/driver-documents", {
      method: "POST",
      body: formData,
    });

    const workspace = await loadWorkspacePayload();
    renderWorkspace(lastSession, workspace);
    renderDriverDocuments(workspace);
    showSuccess(driverDocumentSuccess, "Document uploaded successfully.");
    driverDocumentForm.reset();
    renderDocumentTypeOptions();
  } catch (error) {
    showSuccess(driverDocumentSuccess, error.message);
  }
});

fleetForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  hideSuccess(fleetFormSuccess);

  const payload = {
    city_id: Number(fleetCity.value),
    company_name: document.querySelector("#fleet-company").value.trim(),
    fleet_size: document.querySelector("#fleet-size").value.trim(),
    business_model: document.querySelector("#fleet-business-model").value,
    use_case: document.querySelector("#fleet-model").value,
    support_phone: document.querySelector("#fleet-support-phone").value.trim() || null,
    support_email: document.querySelector("#fleet-support-email").value.trim() || null,
    notes: document.querySelector("#fleet-notes").value.trim() || null,
  };

  try {
    const response = await fetchJson("/onboarding/fleet", {
      method: "PATCH",
      body: JSON.stringify(payload),
    });
    renderWorkspace(lastSession, response.workspace);
    showSuccess(fleetFormSuccess, "Fleet details saved. The team can continue your business onboarding from here.");
  } catch (error) {
    showSuccess(fleetFormSuccess, error.message);
  }
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

    lastSession = session;
    const [references, workspace] = await Promise.all([
      loadReferenceData(),
      loadWorkspacePayload(),
    ]);
    referenceData = references;
    renderWorkspace(session, workspace);
    populateReferenceDrivenFields(session, workspace);

    if (!referencesAreSeeded()) {
      workspaceStatusBanner.querySelector("p").textContent =
        "Some setup lists are not available yet. Add cities, service types, and vehicle lists so every onboarding form loads correctly.";
    }
  } catch {
    window.location.href = "login.html";
  }
});
