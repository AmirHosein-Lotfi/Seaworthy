alter table public.users enable row level security;

create policy "users can read own row"
  on public.users
  for select
  using (auth.uid() = id);

alter table public.projects enable row level security;

create policy "owners can manage own projects"
  on public.projects
  for all
  using (auth.uid() = user_id);
