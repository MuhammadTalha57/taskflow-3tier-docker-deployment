import { useEffect, useState, useCallback } from 'react';
import { api } from './api.js';

export default function App() {
  const [tasks, setTasks] = useState([]);
  const [title, setTitle] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editingId, setEditingId] = useState(null);
  const [editingTitle, setEditingTitle] = useState('');

  const loadTasks = useCallback(async () => {
    try {
      setError(null);
      const data = await api.listTasks();
      setTasks(data);
    } catch (err) {
      setError(`Could not reach the API: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadTasks();
  }, [loadTasks]);

  const handleCreate = async (e) => {
    e.preventDefault();
    if (!title.trim()) return;
    try {
      await api.createTask(title.trim());
      setTitle('');
      loadTasks();
    } catch (err) {
      setError(err.message);
    }
  };

  const toggleDone = async (task) => {
    try {
      await api.updateTask(task.id, { done: !task.done });
      loadTasks();
    } catch (err) {
      setError(err.message);
    }
  };

  const startEdit = (task) => {
    setEditingId(task.id);
    setEditingTitle(task.title);
  };

  const saveEdit = async (id) => {
    if (!editingTitle.trim()) return;
    try {
      await api.updateTask(id, { title: editingTitle.trim() });
      setEditingId(null);
      loadTasks();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDelete = async (id) => {
    try {
      await api.deleteTask(id);
      loadTasks();
    } catch (err) {
      setError(err.message);
    }
  };

  const doneCount = tasks.filter((t) => t.done).length;

  return (
    <div className="shell">
      <header className="topbar">
        <div className="brand">
          <span className="dot" />
          TaskFlow
        </div>
        <div className="stat-line">
          <span>{tasks.length} tasks</span>
          <span className="sep">/</span>
          <span>{doneCount} done</span>
        </div>
      </header>

      <main className="panel">
        <form className="composer" onSubmit={handleCreate}>
          <input
            className="input"
            type="text"
            placeholder="describe a task..."
            value={title}
            onChange={(e) => setTitle(e.target.value)}
          />
          <button className="btn btn-primary" type="submit">
            add
          </button>
        </form>

        {error && <div className="banner banner-error">{error}</div>}
        {loading && <div className="banner">loading tasks…</div>}

        {!loading && tasks.length === 0 && !error && (
          <div className="empty">no tasks yet — add one above</div>
        )}

        <ul className="list">
          {tasks.map((task) => (
            <li key={task.id} className={`row ${task.done ? 'row-done' : ''}`}>
              <button
                className="check"
                onClick={() => toggleDone(task)}
                aria-label={task.done ? 'mark as not done' : 'mark as done'}
              >
                {task.done ? '✓' : ''}
              </button>

              {editingId === task.id ? (
                <input
                  className="input input-inline"
                  value={editingTitle}
                  autoFocus
                  onChange={(e) => setEditingTitle(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && saveEdit(task.id)}
                  onBlur={() => saveEdit(task.id)}
                />
              ) : (
                <span className="title" onDoubleClick={() => startEdit(task)}>
                  {task.title}
                </span>
              )}

              <span className="id">#{task.id}</span>
              <button className="btn btn-ghost" onClick={() => startEdit(task)}>
                edit
              </button>
              <button className="btn btn-danger" onClick={() => handleDelete(task.id)}>
                delete
              </button>
            </li>
          ))}
        </ul>
      </main>

      <footer className="footnote">
        frontend → backend → postgres · double-click a task to rename it
      </footer>
    </div>
  );
}
