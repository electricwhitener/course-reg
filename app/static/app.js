// Shared helpers for every page: API calls, the "Login as" student, and toasts.

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

// The student chosen in the navbar switcher (there is no real login). Remembered per browser.
function currentStudent() {
  return Number(document.getElementById("student-switcher").value);
}

async function initStudentSwitcher() {
  const select = document.getElementById("student-switcher");
  const students = await api("/api/students");
  let saved = null;
  try { saved = localStorage.getItem("studentId"); } catch (_) {}
  select.innerHTML = students
    .map((s) => `<option value="${s.student_id}">${s.student_id}. ${s.name}</option>`)
    .join("");
  if (saved && students.some((s) => String(s.student_id) === saved)) select.value = saved;
  select.addEventListener("change", () => {
    try { localStorage.setItem("studentId", select.value); } catch (_) {}
    document.dispatchEvent(new CustomEvent("student-changed", { detail: currentStudent() }));
  });
}

// kind: success | warning | danger | info
function toast(message, kind = "info") {
  const el = document.createElement("div");
  el.className = `toast align-items-center text-bg-${kind} border-0`;
  el.setAttribute("role", "status");
  el.innerHTML = `<div class="d-flex"><div class="toast-body"></div>
    <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button></div>`;
  el.querySelector(".toast-body").textContent = message;
  document.getElementById("toasts").appendChild(el);
  el.addEventListener("hidden.bs.toast", () => el.remove());
  new bootstrap.Toast(el, { delay: 4000 }).show();
}

initStudentSwitcher();
