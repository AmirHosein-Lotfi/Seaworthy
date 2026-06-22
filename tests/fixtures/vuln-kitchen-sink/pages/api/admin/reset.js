import db from '../../../lib/db'

export default async function handler(req, res) {
  await db.query('DELETE FROM sessions')
  res.status(200).json({ ok: true })
}
