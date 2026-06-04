# Profile Management

## What a Profile Is

A profile is the user's **master data store** — their complete career history. It is the raw input that every tailored CV is generated from. Users fill it in once and the system draws from it every time they apply to a job.

This maps directly to your value proposition: the profile is the base CV the user submits. Everything else is derived from it.

---

## Current Implementation

### Database table: `public.profiles`

```sql
user_id uuid PRIMARY KEY        -- same as auth.users.id
first_name text
last_name text
email text
phone_number text
location text
website text
linkedin_url text
github_url text
is_admin boolean DEFAULT false

-- Career data (JSONB arrays)
work_experience jsonb DEFAULT '[]'
education jsonb DEFAULT '[]'
skills jsonb DEFAULT '[]'
projects jsonb DEFAULT '[]'
certifications jsonb DEFAULT '[]'
```

RLS policy: `user_id = auth.uid()` — users can only read and write their own profile.

### Server actions

Located in `src/utils/actions/profiles/actions.ts`:

| Function | What it does |
|---|---|
| `updateProfile(data)` | Partial update — merges new data into existing profile |
| `importResume(file)` | Parses an uploaded CV file and populates profile fields in bulk |

### Analytics trigger

When a profile has `first_name`, `last_name`, and `email` set for the first time, it fires the `ProfileCreated` PostHog event. This is the signal that a user has completed onboarding.

---

## Profile Components

Located in `src/components/profile/`:

- Personal info form (name, contact, links)
- Work experience editor (TipTap for descriptions)
- Education editor
- Skills editor
- Projects editor
- Certifications editor

All editors follow the same pattern: local state → debounced save → `updateProfile()` server action.

---

## How Profile Relates to Resume Creation

When a user tailors a CV for a job:

1. The system reads their full profile
2. Passes it to the AI along with the job description
3. The AI selects and rewrites relevant sections
4. The output is saved as a new `resumes` row (not modifying the profile)

The profile is **never modified** by AI tailoring — it is always the source of truth. The resume is a derived, read-only snapshot for that job application.

---

## Profile Completeness

Today there is no explicit completeness score. For your value proposition, you should add one — users need to understand that a sparse profile produces a weak CV.

### Suggested completeness calculation

```typescript
export function getProfileCompleteness(profile: Profile): number {
  let score = 0;
  if (profile.first_name && profile.last_name) score += 10;
  if (profile.email) score += 5;
  if (profile.phone_number) score += 5;
  if (profile.location) score += 5;
  if (profile.linkedin_url) score += 5;
  if (profile.work_experience.length >= 1) score += 20;
  if (profile.work_experience.length >= 2) score += 10;
  if (profile.education.length >= 1) score += 15;
  if (profile.skills.length >= 1) score += 10;
  if (profile.projects.length >= 1) score += 10;
  if (profile.professional_summary) score += 5;  // add this field
  return score; // max 100
}
```

Show this as a progress bar on the profile page. Block CV generation if score < 40 with a prompt to complete the profile.

---

## CV Import (Existing Feature)

The `importResume()` action accepts a file upload and uses AI to parse it into structured profile data. This is the fastest onboarding path — user uploads their existing CV and their profile is populated in seconds.

This should be the **first screen** after signup. The current onboarding flow does not make this prominent enough.

### Suggested onboarding flow

```
Sign up
  → "Upload your current CV" (importResume)
  → Profile pre-filled, user reviews and edits
  → Profile completeness reaches threshold
  → "Now apply to your first job" CTA
```

---

## Data Isolation & Security

- RLS ensures users cannot access other users' profiles
- The `is_admin` flag is only writable via the service role (not by the user themselves) — enforced at the database level
- Profile data is never sent to the client in bulk — it is fetched per-section as the user navigates
- When passed to AI, profile data should be sanitised of PII that is not relevant to the job (e.g. strip phone number from the AI prompt, only include it in the final PDF)

---

## Future: Profile Versioning

As users update their profile over time, older tailored CVs become stale (they were generated from an older version of the profile). Consider snapshotting the profile at the time of CV generation into the `resumes` row. The `resumes` table already stores the full content independently, so this is already handled — the resume does not pull from the profile at render time, it stores its own copy of the data.
