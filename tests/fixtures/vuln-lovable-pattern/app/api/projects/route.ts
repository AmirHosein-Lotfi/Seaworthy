import { createClient } from '@supabase/supabase-js'
import { NextRequest } from 'next/server'

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!)

// Updates a project by id. Anyone who can guess/enumerate an id can edit any
// project — there is no check that the caller actually owns this project.
export async function PUT(req: NextRequest) {
  const body = await req.json()
  const { id, ...fields } = body

  const { data, error } = await supabase
    .from('projects')
    .update(fields)
    .eq('id', id)

  return Response.json({ data, error })
}
