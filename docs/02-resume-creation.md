# Resume Creation & Frontend Representation

## Value Proposition Shift

The existing product is a **resume builder**. Your new value proposition is a **job application engine**:

1. User creates their profile (once)
2. User uploads or pastes a job description
3. The platform generates a CV tailored to that specific job
4. (Future) The platform submits the application directly

This changes the primary user journey from "build a resume" to "apply for a job."

---

## How Resumes Are Created Today

### Server actions

All resume logic lives in:

- `src/utils/actions/resumes/actions.ts` — CRUD + AI generation
- `src/utils/actions/resumes/ai.ts` — AI-specific operations

**Key functions:**

| Function | What it does |
|---|---|
| `createResume()` | Creates a base resume, enforces quota |
| `tailorResume()` | Takes a base resume + job description, returns AI-tailored version |
| `generateWorkExperienceFromDescription()` | AI rewrites bullet points for a role |
| `analyzeResumeFitToJob()` | Scores the resume against job keywords (ATS check) |
| `runTrackedAIRequest()` | Wrapper that records usage events before/after every AI call |

### Resume quota enforcement

`src/lib/resume-limits.ts` enforces:
- Free users: 2 base resumes, 4 tailored resumes
- Pro users: unlimited

Under the new credits model, **remove these hard limits**. The credit deduction is the gate instead.

### Data flow for tailored resume

```
User selects job description
    → POST to tailorResume() server action
    → assertResumeQuota() / deductCredits()
    → AI call via Vercel AI SDK (streamText / generateText)
    → Save result to resumes table
    → Return resume id to client
    → Client navigates to /resumes/[id]
```

---

## Resume Data Structure

Stored in `public.resumes` as a mix of flat columns and JSONB:

```typescript
interface Resume {
  id: string
  user_id: string
  job_id: string | null         // linked job description
  is_base_resume: boolean
  name: string                  // internal name, not shown on CV
  resume_title: string | null   // shown on CV header
  target_role: string | null

  // Contact info (flat columns)
  first_name, last_name, email, phone_number, location
  website, linkedin_url, github_url

  // Content (JSONB arrays)
  professional_summary: string
  work_experience: WorkExperience[]
  education: Education[]
  skills: Skill[]
  projects: Project[]
  certifications: Certification[]

  // Layout (JSONB)
  section_order: string[]       // drag-and-drop order
  section_configs: SectionConfigs
  document_settings: DocumentSettings
  cover_letter: CoverLetter | null
}
```

### `document_settings` controls PDF layout

```typescript
interface DocumentSettings {
  document_font_size: number        // default 10
  document_line_height: number      // default 1.5
  document_margin_vertical: number  // default 36
  document_margin_horizontal: number
  header_name_size: number          // default 24
  // per-section margin/spacing controls
  experience_margin_top: number
  skills_item_spacing: number
  // ... etc
}
```

---

## Frontend Representation

### Resume editor

The resume editor lives in `src/components/resume/editor/`. It is a client-side component that:

1. Receives the resume object as a prop from a server component
2. Maintains local state for real-time editing
3. Debounces saves back to Supabase via server actions
4. Uses **TipTap** for rich text editing in description fields

### PDF rendering

PDF output is generated with **React PDF** (`@react-pdf/renderer`). The resume data is passed as props to a React component tree that renders PDF primitives (`<Document>`, `<Page>`, `<View>`, `<Text>`).

The PDF component reads `document_settings` for all spacing/font values, so visual changes in the editor are reflected in the PDF without a full re-render.

### Live preview

The editor shows a side-by-side view:
- Left: form inputs
- Right: live PDF preview (rendered in an iframe via `react-pdf`)

---

## Changes Needed for the New Value Proposition

### 1. Rename the primary action

Change the main CTA from "Create Resume" to "Apply for Job" or "Tailor My CV." This is a UI-only change in the dashboard component.

### 2. Make job description the entry point

Currently the flow is: create resume → optionally link to a job.

New flow should be: paste job description → system generates tailored CV from your profile.

This means the `jobs` table entry and the AI tailoring happen in the **same step**, not separately.

**New server action:**

```typescript
export async function applyToJob(input: {
  userId: string
  jobDescriptionText: string
  baseResumeId: string
}): Promise<{ resumeId: string; jobId: string }> {
  // 1. Deduct credits
  // 2. Create job record from description text
  // 3. Call AI to extract job title, company, keywords
  // 4. Call tailorResume() with the extracted job data
  // 5. Return the new resume id
}
```

### 3. Job description input component

Add a step before resume tailoring:

```
[ Paste job description here ]
[ or import from URL (future) ]
→ "Generate My CV" button (shows credit cost)
```

### 4. Applications dashboard

Replace the current "Resumes" list with an "Applications" list where each row is:

```
Company Name | Role | Date | CV status | ATS Score
Acme Corp    | SWE  | Today | Generated | 87%
```

Each tailored resume maps to one application.

---

## AI Prompt Strategy

The quality of tailoring depends on the prompts in `src/lib/prompts.ts`. For the new value proposition, the tailoring prompt should:

1. Extract keywords from the job description
2. Reorder skills to match job requirements
3. Rewrite bullet points to mirror the language in the job description
4. Flag gaps between the CV and job requirements

This is already partially done — the key improvement is making keyword extraction explicit and showing the user which keywords were matched.
