# Product Plan — Job Application Engine

## Vision

A platform where a user uploads their career history once, then generates a professionally tailored CV and cover letter for any job in under 60 seconds — and tracks every application they make.

---

## Epics & User Stories

### Epic 1 — Onboarding

The first experience a user has with the platform. The goal is to get a user from signup to their first tailored CV as fast as possible.

---

**US-01 — Sign up with email**
> As a new user, I want to create an account with my email and password so that my data is saved and private to me.

Acceptance criteria:
- User can sign up with email + password
- Email verification is sent
- On verification, user is redirected to the onboarding flow
- Duplicate emails are rejected with a clear message

---

**US-02 — Upload existing CV to populate profile**
> As a new user, I want to upload my existing CV so that my profile is filled in automatically without me having to type everything from scratch.

Acceptance criteria:
- User can upload a PDF or DOCX file
- AI parses the file and populates: work experience, education, skills, projects
- User is shown a preview of the extracted data and can correct it before saving
- If parsing fails, user is shown a clear error and falls back to manual entry
- Upload costs 0 credits (it is part of onboarding)

---

**US-03 — Fill profile manually**
> As a new user who does not have a CV file, I want to fill in my profile manually so that I can still use the platform.

Acceptance criteria:
- User can enter personal info, work experience, education, skills, projects, certifications
- Each section can be saved independently
- User can return and edit any section at any time
- Profile shows a completeness percentage

---

**US-04 — See profile completeness**
> As a user, I want to see how complete my profile is so that I know whether it is strong enough to generate a good CV.

Acceptance criteria:
- A progress indicator (e.g. 70% complete) is shown on the profile page
- Each section that is missing or thin is flagged with a prompt to improve it
- Generating a CV is blocked if profile completeness is below 40%, with an explanation
- Completeness score updates in real time as the user adds information

---

**US-05 — Receive welcome credits on signup**
> As a new user, I want to receive free credits when I sign up so that I can try the platform before paying.

Acceptance criteria:
- User receives a defined number of free credits on account creation (e.g. 20 credits)
- Credits are visible immediately after signup
- A banner explains what the credits can be used for

---

### Epic 2 — Profile Management

The profile is the master record of a user's career history. It must be easy to keep up to date.

---

**US-06 — Edit work experience**
> As a user, I want to add, edit, and remove work experience entries so that my profile reflects my current career history.

Acceptance criteria:
- User can add a new role with: job title, company, location, start date, end date, description, responsibilities
- Entries can be reordered by drag and drop
- Changes are saved automatically (no explicit save button needed)
- Deleting an entry asks for confirmation

---

**US-07 — Edit education**
> As a user, I want to manage my education history so that it appears correctly on generated CVs.

Acceptance criteria:
- User can add degree, institution, location, graduation date, GPA, and achievements
- Multiple entries supported
- Changes auto-save

---

**US-08 — Edit skills**
> As a user, I want to group my skills by category so that the CV presents them in an organised way.

Acceptance criteria:
- User can create named skill categories (e.g. "Languages", "Frameworks", "Tools")
- User can add multiple skills per category
- Categories and skills can be reordered
- Changes auto-save

---

**US-09 — Edit projects and certifications**
> As a user, I want to add personal projects and certifications to my profile so that they can appear on tailored CVs when relevant.

Acceptance criteria:
- Projects: name, description, technologies, URL, dates
- Certifications: name, issuer, date, URL
- Both sections optional
- Changes auto-save

---

**US-10 — Re-import CV to update profile**
> As a returning user who has a new version of my CV, I want to re-upload it so that my profile is updated without me having to edit every field.

Acceptance criteria:
- User can upload a new CV at any time from the profile page
- User is shown a diff of what will change before confirming
- Existing data is not overwritten without user confirmation

---

### Epic 3 — Credits & Billing

Users buy credits upfront and spend them on actions. This is the revenue engine.

---

**US-11 — See my credit balance**
> As a user, I want to see my current credit balance at all times so that I know how many actions I can still perform.

Acceptance criteria:
- Credit balance is shown in the navigation bar on every page
- Balance updates immediately after a purchase or after spending credits
- Clicking the balance takes the user to the credits/billing page

---

**US-12 — Buy a credit bundle**
> As a user, I want to purchase a bundle of credits so that I can continue using the platform.

Acceptance criteria:
- User is shown at least three bundle options (e.g. Starter / Standard / Pro) with clear pricing
- Clicking a bundle opens Stripe Checkout
- After successful payment, credits are added to the account within seconds
- User receives a confirmation message and sees the updated balance
- Failed payments show a clear error message

---

**US-13 — See what credits cost**
> As a user, I want to see how many credits each action costs before I perform it so that I can make an informed decision.

Acceptance criteria:
- Every action button that costs credits shows the credit cost (e.g. "Generate CV — 10 credits")
- The credits page lists all actions and their costs
- If a user has insufficient credits, the action button is disabled and a "Buy Credits" prompt is shown

---

**US-14 — See my credit transaction history**
> As a user, I want to see a history of how I have spent and purchased credits so that I can understand my usage.

Acceptance criteria:
- A ledger view shows each transaction: date, action, amount (positive or negative), running balance
- Purchases and spends are clearly distinguished
- History is paginated

---

**US-15 — Receive a refund if an action fails**
> As a user, if an AI action fails after I have been charged credits, I want those credits refunded automatically so that I am not penalised for a technical error.

Acceptance criteria:
- If the AI call fails (timeout, provider error), credits are returned within the same request
- A notification confirms the refund
- Failed actions are logged for internal review

---

### Epic 4 — Job Application Flow

This is the core value proposition. User pastes a job description, gets a tailored CV.

---

**US-16 — Start a new job application**
> As a user, I want to paste a job description and have the platform generate a tailored CV from my profile so that I can apply with the best possible version of my experience.

Acceptance criteria:
- User pastes job description text (or types it in)
- User selects which base profile to generate from (if they have more than one)
- User can see the credit cost before confirming
- On confirmation, the AI generates a tailored CV
- User is navigated to the tailored CV editor when generation is complete
- Generation takes under 30 seconds

---

**US-17 — Review and edit the tailored CV**
> As a user, I want to review and make manual edits to the tailored CV before downloading it so that I can fix anything the AI got wrong.

Acceptance criteria:
- All sections of the tailored CV are editable inline
- Changes auto-save
- User can see a live PDF preview alongside the editor
- User can reorder sections by drag and drop
- User can toggle sections on/off (e.g. hide certifications for a specific application)

---

**US-18 — Download the tailored CV as a PDF**
> As a user, I want to download my tailored CV as a PDF so that I can submit it with my job application.

Acceptance criteria:
- A "Download PDF" button is always visible in the CV editor
- The downloaded file is named sensibly (e.g. "John-Smith-Acme-Corp-SWE.pdf")
- The PDF renders correctly with proper formatting and no clipped text
- Download is free (no additional credit cost)

---

**US-19 — Generate a cover letter for the application**
> As a user, I want to generate a cover letter tailored to the job description so that I have a complete application package.

Acceptance criteria:
- "Generate Cover Letter" button is available from the CV editor
- Cover letter uses profile data and the job description as input
- User can edit the cover letter inline
- Cover letter can be downloaded as a separate PDF or included in the same document
- Costs 5 credits

---

**US-20 — See ATS compatibility score**
> As a user, I want to see how well my tailored CV matches the job description so that I know if it will pass automated screening.

Acceptance criteria:
- After generation, an ATS score (e.g. 87%) is shown
- Key matched keywords are highlighted
- Missing keywords from the job description are listed with suggestions
- Score updates if the user edits the CV
- Costs 3 credits (or is included with the tailored CV generation)

---

**US-21 — Name and organise an application**
> As a user, I want to give each application a name and see the company and role so that I can find it later.

Acceptance criteria:
- The system auto-extracts company name and role from the job description
- User can override the name
- Applications are grouped by status (generated, submitted, interviewing, rejected, offer)
- User can manually update the status

---

### Epic 5 — Applications Dashboard

Users need to track all the jobs they have applied to.

---

**US-22 — See all my applications**
> As a user, I want to see a list of all the jobs I have applied to so that I can track my job search in one place.

Acceptance criteria:
- Dashboard shows each application with: company, role, date generated, ATS score, status
- Applications are sorted by most recent by default
- User can filter by status
- Clicking an application opens the tailored CV editor for that application

---

**US-23 — Update application status**
> As a user, I want to mark an application as "submitted", "interviewing", "rejected", or "offer received" so that I can track where I am in each process.

Acceptance criteria:
- Status can be updated from the dashboard without opening the full editor
- Status changes are saved immediately
- A summary count at the top of the dashboard shows how many applications are in each state

---

**US-24 — Delete an application**
> As a user, I want to delete an application I no longer need so that my dashboard stays clean.

Acceptance criteria:
- User is asked to confirm before deletion
- Deletion removes the tailored CV and the job record
- Credits spent on the deleted application are not refunded

---

### Epic 6 — AI Chat Assistant

An assistant that helps users improve their CV within the context of a specific job.

---

**US-25 — Chat with the AI about my CV**
> As a user, I want to ask the AI to improve specific parts of my CV so that I can iterate on it without regenerating the whole thing.

Acceptance criteria:
- A chat panel is available inside the CV editor
- The AI has context of the current CV and the job description
- User can ask things like "rewrite my summary to be more concise" or "add more impact to my third bullet point"
- The AI's suggested changes can be applied with one click or dismissed
- Each message costs 1 credit

---

**US-26 — Ask for interview preparation tips**
> As a user, I want to ask the AI what questions I might be asked based on the job description so that I can prepare for the interview.

Acceptance criteria:
- Available from the application detail view
- AI generates 5-10 likely interview questions based on the job description and the user's CV
- Questions are grouped by type (technical, behavioural, role-specific)
- Costs 5 credits

---

### Epic 7 — Admin & Monitoring

Internal tools for managing the platform and monitoring costs.

---

**US-27 — See platform-wide AI cost**
> As an admin, I want to see total AI spend by day, by model, and by action type so that I can monitor my costs and margins.

Acceptance criteria:
- Admin dashboard shows daily AI cost for the last 30 days
- Breakdown by model and by action (tailoring, cover letter, chat, etc.)
- Average cost per tailored CV is shown
- Data refreshes at least once per hour

---

**US-28 — See top users by spend**
> As an admin, I want to see which users are generating the most AI cost so that I can identify unusual usage patterns.

Acceptance criteria:
- Table of top 20 users by AI cost (last 30 days)
- Shows: user email, number of requests, total tokens, estimated cost
- Admin can flag a user for manual review

---

**US-29 — See credit purchase revenue**
> As an admin, I want to see daily credit purchase revenue so that I can track whether the business is growing.

Acceptance criteria:
- Chart of daily revenue from credit purchases (last 30 days)
- Total credits sold vs total credits spent
- Average revenue per purchasing user

---

**US-30 — Manually adjust a user's credit balance**
> As an admin, I want to add or remove credits from a user's account so that I can handle refunds, compensation, or testing.

Acceptance criteria:
- Admin can search for a user by email
- Admin can add or subtract credits with a reason note
- The adjustment appears in the user's credit ledger as "admin_adjustment"
- Action is logged with the admin's user ID

---

## Summary Table

| # | User Story | Epic | Complexity | Priority |
|---|---|---|---|---|
| US-01 | Sign up with email | Onboarding | Low | P0 |
| US-02 | Upload CV to populate profile | Onboarding | High | P0 |
| US-03 | Fill profile manually | Onboarding | Medium | P0 |
| US-04 | See profile completeness | Onboarding | Low | P1 |
| US-05 | Welcome credits on signup | Onboarding | Low | P0 |
| US-06 | Edit work experience | Profile | Medium | P0 |
| US-07 | Edit education | Profile | Low | P0 |
| US-08 | Edit skills | Profile | Low | P0 |
| US-09 | Edit projects and certifications | Profile | Low | P1 |
| US-10 | Re-import CV | Profile | Medium | P2 |
| US-11 | See credit balance | Credits | Low | P0 |
| US-12 | Buy a credit bundle | Credits | Medium | P0 |
| US-13 | See credit cost per action | Credits | Low | P0 |
| US-14 | Credit transaction history | Credits | Low | P1 |
| US-15 | Refund on failed action | Credits | Medium | P1 |
| US-16 | Start a job application | Application | High | P0 |
| US-17 | Review and edit tailored CV | Application | High | P0 |
| US-18 | Download CV as PDF | Application | Low | P0 |
| US-19 | Generate cover letter | Application | Medium | P1 |
| US-20 | ATS score | Application | Medium | P1 |
| US-21 | Name and organise application | Application | Low | P1 |
| US-22 | See all applications | Dashboard | Medium | P0 |
| US-23 | Update application status | Dashboard | Low | P1 |
| US-24 | Delete application | Dashboard | Low | P2 |
| US-25 | Chat with AI about CV | AI Chat | High | P1 |
| US-26 | Interview prep tips | AI Chat | Medium | P2 |
| US-27 | Platform AI cost monitoring | Admin | Medium | P1 |
| US-28 | Top users by spend | Admin | Low | P1 |
| US-29 | Credit purchase revenue | Admin | Low | P1 |
| US-30 | Manual credit adjustment | Admin | Low | P2 |

---

## Priority Definitions

| Priority | Meaning |
|---|---|
| **P0** | Must exist for the product to function. Build before launch. |
| **P1** | Important for retention and monetisation. Build in the first month after launch. |
| **P2** | Nice to have. Build when P1 is complete. |

## Suggested Build Order

**Phase 1 — Core (P0 stories)**
Get a user from signup → profile → first tailored CV → PDF download → credit purchase. This is the entire value proposition in one flow.

**Phase 2 — Retention (P1 stories)**
ATS score, cover letter, application tracking, credit history, AI chat. These turn a one-time user into a repeat user.

**Phase 3 — Operations (P2 stories)**
Admin monitoring, interview prep, re-import. These support the business operationally once users exist.
