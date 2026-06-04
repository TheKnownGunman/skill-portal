# System Documentation

This folder documents how the platform works and what it takes to evolve it into a job application engine with a credit-based monetisation model.

## Documents

| File | What it covers |
|---|---|
| [01-monetisation.md](01-monetisation.md) | Credits system design, Stripe changes, database schema, deduction logic |
| [02-resume-creation.md](02-resume-creation.md) | How CVs are built, the new "apply to job" flow, AI prompt strategy |
| [03-profiles.md](03-profiles.md) | Profile data model, completeness scoring, onboarding flow |
| [04-token-usage-monitoring.md](04-token-usage-monitoring.md) | AI cost tracking, runtime measurement, cost per action |
| [05-ui-redesign.md](05-ui-redesign.md) | How to rebrand, change colours/fonts, restructure layout |
| [06-scalability.md](06-scalability.md) | Infrastructure limits, key metrics, scaling checklist by stage |

## Priority Order for Implementation

1. **Credits system** (`01-monetisation.md`) — this is the core business model change. Everything else builds on it.
2. **New "apply to job" flow** (`02-resume-creation.md`) — the value proposition change. Requires credits to be in place first.
3. **Token cost tracking** (`04-token-usage-monitoring.md`) — add `duration_ms` and the cost view immediately. You need this data from day one.
4. **Profile completeness** (`03-profiles.md`) — improves activation rate and output quality.
5. **Rebrand** (`05-ui-redesign.md`) — do this after the core flow works.
6. **Infrastructure upgrades** (`06-scalability.md`) — Vercel Pro and Supabase Pro before launch.
