-- Sathena Planner: schema voor Supabase
-- Plak dit in Supabase → SQL Editor → Run.

create table if not exists public.docs (
  coll        text not null,
  id          text not null,
  data        jsonb not null,
  updated_at  timestamptz not null default now(),
  primary key (coll, id)
);

-- Iedereen met de anon key mag lezen en schrijven (de app regelt de login zelf).
alter table public.docs enable row level security;
drop policy if exists "planner_all" on public.docs;
create policy "planner_all" on public.docs for all
  to anon, authenticated using (true) with check (true);

-- Realtime: wijzigingen direct bij alle gebruikers zichtbaar.
alter table public.docs replica identity full;
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='docs') then
    alter publication supabase_realtime add table public.docs;
  end if;
end $$;
