// Vite exposes env vars prefixed with VITE_ to client code, inlined at build time.
// This lets the same image be pointed at different backends by rebuilding
// with a different .env, without touching application code.
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api';

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Request failed with status ${res.status}`);
  }

  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  listTasks: () => request('/tasks'),
  createTask: (title) =>
    request('/tasks', { method: 'POST', body: JSON.stringify({ title }) }),
  updateTask: (id, patch) =>
    request(`/tasks/${id}`, { method: 'PUT', body: JSON.stringify(patch) }),
  deleteTask: (id) => request(`/tasks/${id}`, { method: 'DELETE' }),
};
