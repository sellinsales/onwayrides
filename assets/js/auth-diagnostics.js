const config = window.ONWAYRIDES_WEB_CONFIG ?? {};

const runButton = document.querySelector("#run-diagnostics-button");
const summaryGrid = document.querySelector("#diagnostic-summary-grid");
const tableBody = document.querySelector("#diagnostic-table-body");
const timestampSlot = document.querySelector("#diagnostic-timestamp");

function buildApiUrl(path) {
  return `${String(config.apiBaseUrl ?? "").replace(/\/$/, "")}${path}`;
}

function formatStatus(ok, warn = false) {
  if (ok) {
    return '<span class="pill good">Pass</span>';
  }

  return warn
    ? '<span class="pill warn">Warning</span>'
    : '<span class="pill warn">Fail</span>';
}

function addResult(results, name, ok, details, warn = false) {
  results.push({ name, ok, details, warn });
}

async function checkSessionStorage(results) {
  try {
    const key = "__onwayrides_diag__";
    sessionStorage.setItem(key, "ok");
    const value = sessionStorage.getItem(key);
    sessionStorage.removeItem(key);
    addResult(
      results,
      "sessionStorage access",
      value === "ok",
      value === "ok"
        ? "Read/write access is working for this tab."
        : "sessionStorage write succeeded but read-back failed.",
    );
  } catch (error) {
    addResult(
      results,
      "sessionStorage access",
      false,
      `sessionStorage is unavailable: ${error.message}`,
    );
  }
}

function checkPopup(results) {
  let popup = null;

  try {
    popup = window.open("about:blank", "_blank", "popup,width=420,height=640");
    const opened = popup !== null;
    let closable = false;
    let closedPropertyReadable = false;

    if (popup) {
      try {
        closedPropertyReadable = typeof popup.closed === "boolean";
      } catch {
        closedPropertyReadable = false;
      }

      try {
        popup.close();
        closable = true;
      } catch {
        closable = false;
      }
    }

    addResult(
      results,
      "Popup window behavior",
      opened && closedPropertyReadable && closable,
      opened
        ? closedPropertyReadable && closable
          ? "Browser popup open/close flow looks normal."
          : "Popup opened, but window.close/window.closed behavior is restricted. Check Cross-Origin-Opener-Policy."
        : "Popup could not be opened. Browser popup blocking may be active.",
      opened && (!closedPropertyReadable || !closable),
    );
  } catch (error) {
    addResult(
      results,
      "Popup window behavior",
      false,
      `Popup test failed: ${error.message}`,
    );
  } finally {
    try {
      popup?.close();
    } catch {
      // no-op
    }
  }
}

async function checkHeaders(results) {
  try {
    const response = await fetch(window.location.href, {
      cache: "no-store",
      credentials: "same-origin",
    });

    const coop = response.headers.get("cross-origin-opener-policy");
    const coep = response.headers.get("cross-origin-embedder-policy");
    const corp = response.headers.get("cross-origin-resource-policy");

    addResult(
      results,
      "Current page fetch",
      response.ok,
      `HTTP ${response.status} ${response.statusText}`,
    );

    addResult(
      results,
      "Cross-Origin-Opener-Policy",
      coop === null || coop === "unsafe-none" || coop === "same-origin-allow-popups",
      coop === null
        ? "Header not present on this page."
        : `Current value: ${coop}`,
      coop !== null && coop !== "unsafe-none" && coop !== "same-origin-allow-popups",
    );

    addResult(
      results,
      "Cross-Origin-Embedder-Policy",
      true,
      coep === null ? "Header not present." : `Current value: ${coep}`,
      coep !== null,
    );

    addResult(
      results,
      "Cross-Origin-Resource-Policy",
      true,
      corp === null ? "Header not present." : `Current value: ${corp}`,
      corp !== null,
    );
  } catch (error) {
    addResult(
      results,
      "Current page headers",
      false,
      `Could not fetch the current page to inspect response headers: ${error.message}`,
    );
  }
}

async function checkApi(results) {
  try {
    const response = await fetch(buildApiUrl("/bootstrap"), {
      cache: "no-store",
    });

    if (!response.ok) {
      addResult(
        results,
        "Backend bootstrap endpoint",
        false,
        `API responded with HTTP ${response.status}. Check api.onwayrides.com routing and CORS.`,
      );
      return;
    }

    const data = await response.json();
    addResult(
      results,
      "Backend bootstrap endpoint",
      true,
      `Reachable. Platform: ${data.platform?.name ?? "unknown"}, API version: ${data.platform?.api_version ?? "unknown"}.`,
    );
  } catch (error) {
    addResult(
      results,
      "Backend bootstrap endpoint",
      false,
      `Could not reach ${buildApiUrl("/bootstrap")}: ${error.message}`,
    );
  }
}

function checkConfig(results) {
  const host = window.location.hostname;
  const authDomain = config.firebase?.authDomain ?? "missing";
  const apiBaseUrl = config.apiBaseUrl ?? "missing";

  addResult(
    results,
    "Current hostname",
    true,
    `${host} (${window.location.origin})`,
  );

  addResult(
    results,
    "Firebase authDomain",
    Boolean(authDomain && authDomain !== "missing"),
    authDomain,
  );

  addResult(
    results,
    "Configured API base URL",
    Boolean(apiBaseUrl && apiBaseUrl !== "missing"),
    apiBaseUrl,
  );
}

function render(results) {
  const passed = results.filter((item) => item.ok).length;
  const warned = results.filter((item) => !item.ok && item.warn).length;
  const failed = results.filter((item) => !item.ok && !item.warn).length;

  const summaryCards = [
    ["Checks run", results.length],
    ["Passed", passed],
    ["Warnings", warned],
    ["Failed", failed],
  ];

  summaryGrid.innerHTML = summaryCards
    .map(
      ([label, value]) => `
        <article>
          <strong>${value}</strong>
          <span>${label}</span>
        </article>
      `,
    )
    .join("");

  tableBody.innerHTML = results
    .map(
      (item) => `
        <tr>
          <td><strong>${item.name}</strong></td>
          <td>${formatStatus(item.ok, item.warn)}</td>
          <td><span class="helper-text">${item.details}</span></td>
        </tr>
      `,
    )
    .join("");

  timestampSlot.textContent = `Last run: ${new Date().toLocaleString()}`;
}

async function runDiagnostics() {
  runButton.disabled = true;
  runButton.textContent = "Running...";

  const results = [];
  checkConfig(results);
  await checkSessionStorage(results);
  checkPopup(results);
  await checkHeaders(results);
  await checkApi(results);
  render(results);

  runButton.disabled = false;
  runButton.textContent = "Run checks";
}

runButton?.addEventListener("click", runDiagnostics);
runDiagnostics();
