-- Seattle Desi TV Supabase schema
-- Run in Supabase SQL Editor.

create extension if not exists "pgcrypto";

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  role text not null default 'admin',
  created_at timestamptz default now()
);

alter table public.admins enable row level security;
drop policy if exists "Users can read their own admin row" on public.admins;
create policy "Users can read their own admin row"
on public.admins for select to authenticated
using (user_id = auth.uid() or email = auth.jwt() ->> 'email');

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  date date not null,
  location text not null,
  description text,
  ticket_url text,
  poc_email text,
  poc_phone text,
  image text,
  crew_member_ids uuid[] default '{}',
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table public.events enable row level security;
drop policy if exists "Anyone can view events" on public.events;
drop policy if exists "Logged in users can create events" on public.events;
drop policy if exists "Admins can update events" on public.events;
create policy "Anyone can view events" on public.events for select to public using (true);
create policy "Logged in users can create events" on public.events for insert to authenticated with check (auth.uid() = created_by);
create policy "Admins can update events" on public.events for update to authenticated using (
  exists (select 1 from public.admins a where a.user_id = auth.uid() and lower(a.role) like '%admin%')
) with check (
  exists (select 1 from public.admins a where a.user_id = auth.uid() and lower(a.role) like '%admin%')
);

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  title text not null,
  image text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table public.team_members enable row level security;
drop policy if exists "Anyone can view team members" on public.team_members;
drop policy if exists "Admins can add team members" on public.team_members;
create policy "Anyone can view team members" on public.team_members for select to public using (true);
create policy "Admins can add team members" on public.team_members for insert to authenticated with check (
  exists (select 1 from public.admins a where a.user_id = auth.uid() and lower(a.role) like '%admin%')
);

create table if not exists public.radio_team_members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  title text not null,
  segment_name text not null,
  image text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table public.radio_team_members enable row level security;
drop policy if exists "Anyone can view radio team members" on public.radio_team_members;
drop policy if exists "Admins can add radio team members" on public.radio_team_members;
create policy "Anyone can view radio team members" on public.radio_team_members for select to public using (true);
create policy "Admins can add radio team members" on public.radio_team_members for insert to authenticated with check (
  exists (select 1 from public.admins a where a.user_id = auth.uid() and lower(a.role) like '%admin%')
);

create table if not exists public.event_crew_assignments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  assignment_type text default 'self_selected',
  created_at timestamptz default now(),
  unique(event_id, user_id)
);

alter table public.event_crew_assignments enable row level security;
drop policy if exists "Anyone can view event crew" on public.event_crew_assignments;
drop policy if exists "Crew users can join event crew" on public.event_crew_assignments;
create policy "Anyone can view event crew" on public.event_crew_assignments for select to public using (true);
create policy "Crew users can join event crew" on public.event_crew_assignments for insert to authenticated with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.admins a
    where a.user_id = auth.uid()
    and (lower(a.role) like '%crew%' or lower(a.role) like '%admin%')
  )
);

create table if not exists public.local_businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  website text,
  category text,
  discount text,
  offer text,
  poc_name text,
  poc_email text,
  poc_phone text,
  image text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

alter table public.local_businesses enable row level security;
drop policy if exists "Anyone can view local businesses" on public.local_businesses;
drop policy if exists "Logged in users can create local businesses" on public.local_businesses;
create policy "Anyone can view local businesses" on public.local_businesses for select to public using (true);
create policy "Logged in users can create local businesses" on public.local_businesses for insert to authenticated with check (auth.uid() = created_by);

create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  phone text,
  interest text not null,
  message text,
  created_at timestamptz default now()
);

alter table public.contact_requests enable row level security;
drop policy if exists "Anyone can submit contact requests" on public.contact_requests;
create policy "Anyone can submit contact requests" on public.contact_requests for insert to public with check (true);

insert into storage.buckets (id, name, public)
values
  ('event-images', 'event-images', true),
  ('business-images', 'business-images', true),
  ('team-images', 'team-images', true),
  ('radio-team-images', 'radio-team-images', true)
on conflict (id) do nothing;

drop policy if exists "Public can view media images" on storage.objects;
create policy "Public can view media images"
on storage.objects for select to public
using (bucket_id in ('event-images','business-images','team-images','radio-team-images'));

drop policy if exists "Authenticated users can upload media images" on storage.objects;
create policy "Authenticated users can upload media images"
on storage.objects for insert to authenticated
with check (bucket_id in ('event-images','business-images','team-images','radio-team-images'));

-- Added for multi-image galleries in event and business detail pages.
alter table public.events add column if not exists image_urls text[] default '{}';
alter table public.local_businesses add column if not exists image_urls text[] default '{}';
