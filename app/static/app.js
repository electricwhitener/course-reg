// Shared helpers for every page: API calls, the "Login as" student, theme, DB status and toasts.

// fetch() wrapper: sends/receives JSON and throws the MySQL error message on failure.
async function api(path, { method = "GET", body } = {}) {
  const response = await fetch(path, {
    method,
    headers: body ? { "Content-Type": "application/json" } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || response.statusText);
  return data;
}

// Escapes a database value before it goes into innerHTML.
function esc(value) {
  const entities = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
  return String(value ?? "").replace(/[&<>"']/g, (c) => entities[c]);
}

function initials(name) {
  return name.split(/\s+/).map((word) => word[0]).slice(0, 2).join("").toUpperCase();
}

// The student chosen in the navbar switcher (there is no real login). Remembered per browser.
function currentStudent() {
  return Number(document.getElementById("student-switcher").value);
}

let students = [];

function studentById(id) {
  return students.find((s) => s.student_id === id);
}

function updateAvatar() {
  const student = studentById(currentStudent());
  const avatar = document.getElementById("student-avatar");
  if (!student || !avatar) return;
  avatar.textContent = initials(student.name);
  avatar.title = `${student.name} · ${student.dept_name}`;
}

async function initStudentSwitcher() {
  const select = document.getElementById("student-switcher");
  students = await api("/api/students");
  let saved = null;
  try { saved = localStorage.getItem("studentId"); } catch (_) {}
  select.innerHTML = students
    .map((s) => `<option value="${s.student_id}">${esc(s.name)}</option>`)
    .join("");
  if (saved && students.some((s) => String(s.student_id) === saved)) select.value = saved;
  updateAvatar();
  select.addEventListener("change", () => {
    try { localStorage.setItem("studentId", select.value); } catch (_) {}
    updateAvatar();
    document.dispatchEvent(new CustomEvent("student-changed", { detail: currentStudent() }));
  });
  return students;
}

function initThemeToggle() {
  document.getElementById("theme-toggle").addEventListener("click", () => {
    const root = document.documentElement;
    const next = root.getAttribute("data-bs-theme") === "dark" ? "light" : "dark";
    root.setAttribute("data-bs-theme", next);
    try { localStorage.setItem("theme", next); } catch (_) {}
  });
}

async function initDbStatus() {
  const el = document.getElementById("db-status");
  const label = el.querySelector(".cr-db-label");
  try {
    const health = await api("/api/health");
    el.classList.add("is-up");
    label.textContent = `MySQL ${health.version.split("-")[0]}`;
    el.title = `Connected as ${health.user} to ${health.db}`;
  } catch (err) {
    el.classList.add("is-down");
    label.textContent = "Database offline";
    el.title = err.message;
  }
}

const TOAST_ICONS = {
  success: '<path d="M20 6 9 17l-5-5"/>',
  warning: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  danger: '<path d="M18 6 6 18M6 6l12 12"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
};

// kind: success | warning | danger | info
function toast(message, kind = "info") {
  const el = document.createElement("div");
  el.className = `toast cr-toast cr-toast-${kind}`;
  el.setAttribute("role", "status");
  el.innerHTML = `<div class="cr-toast-inner">
      <span class="cr-toast-icon"><svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor"
        stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">${TOAST_ICONS[kind] || TOAST_ICONS.info}</svg></span>
      <div class="cr-toast-body"></div>
      <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
    </div>`;
  el.querySelector(".cr-toast-body").textContent = message;
  document.getElementById("toasts").appendChild(el);
  el.addEventListener("hidden.bs.toast", () => el.remove());
  new bootstrap.Toast(el, { delay: 4500 }).show();
}

// Pages wait on this before their first load, so currentStudent() is set.
const studentsReady = initStudentSwitcher();
initThemeToggle();
initDbStatus();
