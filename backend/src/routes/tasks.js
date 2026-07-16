import { Router } from 'express';
import pool from '../db.js';

const router = Router();

// GET /api/tasks — list all tasks
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, title, done, created_at FROM tasks ORDER BY id DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('[tasks] GET / failed', err);
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

// POST /api/tasks — create a task
router.post('/', async (req, res) => {
  const { title } = req.body;
  if (!title || typeof title !== 'string' || !title.trim()) {
    return res.status(400).json({ error: 'title is required' });
  }
  try {
    const result = await pool.query(
      'INSERT INTO tasks (title) VALUES ($1) RETURNING id, title, done, created_at',
      [title.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('[tasks] POST / failed', err);
    res.status(500).json({ error: 'Failed to create task' });
  }
});

// PUT /api/tasks/:id — update a task (title and/or done)
router.put('/:id', async (req, res) => {
  const { id } = req.params;
  const { title, done } = req.body;

  if (title === undefined && done === undefined) {
    return res.status(400).json({ error: 'Provide title and/or done to update' });
  }

  try {
    const result = await pool.query(
      `UPDATE tasks
         SET title = COALESCE($1, title),
             done  = COALESCE($2, done)
       WHERE id = $3
       RETURNING id, title, done, created_at`,
      [title ?? null, done ?? null, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('[tasks] PUT /:id failed', err);
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// DELETE /api/tasks/:id — remove a task
router.delete('/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('DELETE FROM tasks WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }
    res.status(204).send();
  } catch (err) {
    console.error('[tasks] DELETE /:id failed', err);
    res.status(500).json({ error: 'Failed to delete task' });
  }
});

export default router;
