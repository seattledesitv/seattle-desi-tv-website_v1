# Seattle Desi TV Platform

A Git-ready Next.js + Supabase media platform for Seattle Desi TV.

## Features

- Broadcast and Classic homepage switch
- YouTube latest videos using YouTube Data API
- Live365 radio metadata and audio stream
- Events with poster upload, ticket link, internal POC fields
- Admin-assigned Desi TV Crew per event
- Crew users can join an event as Desi TV Crew
- Local business directory with offers/discounts
- Public team and radio team pages
- Admin Studio dashboard
- Login, signup, reset password, and magic link
- Contact form for volunteers, interns, RJ/VJ, sponsorships, and media partnerships

## Important security note

Secrets/API keys are not hardcoded. Configure them in `.env.local` locally and in Vercel Environment Variables for deployment.

Copy `.env.local.example`:

```bash
cp .env.local.example .env.local
```

Then fill in:

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_publishable_or_anon_key
NEXT_PUBLIC_YOUTUBE_API_KEY=your_youtube_api_key
NEXT_PUBLIC_YOUTUBE_HANDLE=seattledesitv
NEXT_PUBLIC_LIVE365_META_URL=https://api.live365.com/stations/a45587/nowplaying
NEXT_PUBLIC_LIVE365_STREAM_URL=https://das-edge17-live365-dal02.cdnstream.com/a45587
```

## Run locally

```bash
npm install
npm run dev
```

Open http://localhost:3000.

## Supabase setup

Run:

```sql
-- Supabase SQL Editor
-- paste contents of supabase/schema.sql
```

Then add your admin user:

```sql
insert into public.admins (user_id, email, role)
values ('YOUR_AUTH_USER_UUID', 'seattledesitv@gmail.com', 'super_admin')
on conflict (user_id) do update set role = excluded.role, email = excluded.email;
```

Roles:

- `super_admin` or any role containing `admin`: can access Studio and assign event crew.
- `event_crew` or any role containing `crew`: can join events as Desi TV Crew.
- Admins automatically inherit crew permissions.

## Push to GitHub

```bash
git init
git add .
git commit -m "Initial Seattle Desi TV platform"
git branch -M main
git remote add origin https://github.com/YOURUSERNAME/seattle-desi-tv.git
git push -u origin main
```

## Deploy to Vercel

1. Import the GitHub repo in Vercel.
2. Add the same environment variables from `.env.local.example`.
3. Deploy.
