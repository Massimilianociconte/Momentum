# Supabase CLI workdir

Use the **backend** project directory for all CLI operations:

```bash
cd backend
supabase migration list --linked
supabase db push --linked
supabase db advisors --linked --type security
supabase functions deploy wearable-gateway
```

Migrations live in `backend/supabase/migrations/`.
