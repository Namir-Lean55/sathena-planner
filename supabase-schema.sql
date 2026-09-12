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

-- Geschiedenis van elke wijziging (audit): niets gaat verloren bij overschrijven of verwijderen.
create table if not exists public.docs_history (
  hid         bigserial primary key,
  coll        text not null,
  id          text not null,
  action      text not null,
  data        jsonb,
  changed_at  timestamptz not null default now()
);
create index if not exists docs_history_coll_id_idx on public.docs_history (coll, id, changed_at desc);
alter table public.docs_history enable row level security;
create or replace function public.docs_audit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    insert into public.docs_history (coll,id,action,data) values (old.coll, old.id, 'delete', old.data); return old;
  elsif tg_op = 'UPDATE' then
    insert into public.docs_history (coll,id,action,data) values (old.coll, old.id, 'update', old.data); return new;
  else
    insert into public.docs_history (coll,id,action,data) values (new.coll, new.id, 'insert', new.data); return new;
  end if;
end $$;
drop trigger if exists docs_audit_trg on public.docs;
create trigger docs_audit_trg after insert or update or delete on public.docs for each row execute function public.docs_audit();
