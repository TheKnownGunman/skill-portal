# Changing the Look of the App

## How the UI Is Built

The app uses:

- **Tailwind CSS** — utility classes, configured in `tailwind.config.ts`
- **CSS variables** — theme colours defined in `src/app/globals.css`
- **Shadcn UI** — pre-built accessible components in `src/components/ui/`
- **Radix UI** — the headless primitives underneath Shadcn
- **TipTap** — rich text editor for resume sections

The key insight: **almost everything visual is controlled by CSS variables and Tailwind**. You do not need to touch individual component files to change the overall look.

---

## Where Colours Are Defined

`src/app/globals.css` defines the full theme as HSL CSS variables:

```css
:root {
  --background: 0 0% 100%;          /* page background */
  --foreground: 222.2 84% 4.9%;     /* text colour */
  --primary: 222.2 47.4% 11.2%;     /* buttons, links */
  --primary-foreground: 210 40% 98%;
  --secondary: 210 40% 96.1%;       /* secondary buttons, tags */
  --accent: 210 40% 96.1%;          /* hover states */
  --muted: 210 40% 96.1%;           /* muted text backgrounds */
  --muted-foreground: 215.4 16.3% 46.9%;
  --destructive: 0 84.2% 60.2%;     /* error/delete actions */
  --border: 214.3 31.8% 91.4%;
  --input: 214.3 31.8% 91.4%;
  --ring: 222.2 84% 4.9%;           /* focus ring */
  --radius: 0.5rem;                  /* border radius */
}

.dark {
  /* dark mode overrides */
}
```

**Changing brand colours = editing these variables.** Nothing else needs to change.

### Example: switching to a green brand

```css
:root {
  --primary: 142 76% 36%;           /* emerald green */
  --primary-foreground: 0 0% 100%;
  --accent: 142 76% 95%;
  --ring: 142 76% 36%;
}
```

---

## Where Fonts Are Defined

Fonts are loaded in `src/app/layout.tsx` via `next/font/google`. To change the font:

```typescript
// current
import { Inter } from 'next/font/google'
const font = Inter({ subsets: ['latin'] })

// change to e.g. DM Sans
import { DM_Sans } from 'next/font/google'
const font = DM_Sans({ subsets: ['latin'] })
```

Apply it on the `<html>` tag in the same file. No other changes needed.

---

## Custom UI Utilities

`tailwind.config.ts` defines these custom classes used throughout the app:

| Class | Effect |
|---|---|
| `.glass-card` | Frosted glass effect (backdrop-blur + semi-transparent background) |
| `.hover-card` | Lift effect on hover |
| `animation-blob` | Background blob animation |
| `animation-shine` | Shimmer loading effect |

These are defined in `tailwind.config.ts` under `theme.extend`. Modify or remove them to change the visual feel.

---

## Component Library (Shadcn)

All UI components live in `src/components/ui/`. They are **copied into your repo** (not installed as a package), so you can edit them directly.

Key components and what they affect:

| File | Affects |
|---|---|
| `button.tsx` | All buttons across the app |
| `card.tsx` | Dashboard cards, resume cards |
| `dialog.tsx` | All modals |
| `input.tsx` | All text inputs |
| `badge.tsx` | Status chips, plan badges |
| `tabs.tsx` | Tab navigation in editor |

To change how all buttons look, edit `src/components/ui/button.tsx`. Changes propagate everywhere.

---

## Page-Level Layout

```
src/app/
├── layout.tsx              ← root layout: fonts, providers, header/footer
├── globals.css             ← CSS variables and global styles
├── (dashboard)/
│   ├── layout.tsx          ← dashboard layout: sidebar, auth check
│   └── home/page.tsx       ← home dashboard page
```

The dashboard layout controls the sidebar and overall page structure. The root layout controls the header (`AppHeader`) and footer.

---

## What a Full Redesign Takes

### Level 1: Rebrand (1-2 days)

Change colours, fonts, and logo only.

- Edit CSS variables in `globals.css`
- Change font in `layout.tsx`
- Replace logo SVG/image in `AppHeader`
- Update the site name string (search for "ResumeLM" across the codebase)

### Level 2: Visual refresh (1-2 weeks)

New visual style but same layout and components.

- Edit Shadcn component files in `src/components/ui/`
- Update Tailwind config for new animation/utility classes
- Redesign the landing page (`src/app/page.tsx`)
- Update the dashboard cards and resume list views

### Level 3: Layout restructure (2-4 weeks)

Change the navigation model, dashboard structure, or resume editor layout.

- Redesign `src/app/(dashboard)/layout.tsx`
- Restructure the resume editor components in `src/components/resume/editor/`
- New onboarding flow (new pages + server actions)

### Level 4: Full rebuild (months)

Redesign the PDF template, replace the rich text editor, change the resume data model. Avoid this unless there is a specific reason — the current editor is solid.

---

## Renaming the Product

The name "ResumeLM" appears in:

- `src/app/layout.tsx` — page title and meta tags
- `src/app/page.tsx` — landing page copy
- `README.md`, `CLAUDE.md`, blog content
- The Supabase project name (cosmetic only)
- The Stripe product name (update in Stripe dashboard)
- The Vercel project name (cosmetic only)

Run a search for `ResumeLM` and `resumelm` (case-insensitive) across the codebase to find all instances.

---

## Changing the Value Proposition in the UI

The shift from "resume builder" to "job application engine" requires these UI copy changes:

| Current | New |
|---|---|
| "Create Resume" | "Apply for Job" |
| "My Resumes" | "My Applications" |
| "Base Resume" | "My Profile CV" |
| "Tailored Resume" | "Tailored Application" |
| "Upgrade to Pro" | "Buy Credits" |
| "Resume Builder" | "AI Job Application" |

These are string changes in the component files. Use a global search for the current strings and replace them.
