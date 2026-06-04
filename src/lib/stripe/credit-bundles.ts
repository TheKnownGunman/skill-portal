// Credit bundle definitions.
// Credit amounts and display prices are read from environment variables so they
// can be changed without a code deployment — update the env var and redeploy.
//
// Required env vars (add to Vercel + .env.local):
//   NEXT_PUBLIC_STRIPE_CREDITS_STARTER   — Stripe Price ID for the starter bundle
//   NEXT_PUBLIC_STRIPE_CREDITS_STANDARD  — Stripe Price ID for the standard bundle
//   NEXT_PUBLIC_STRIPE_CREDITS_PRO       — Stripe Price ID for the pro bundle
//   NEXT_PUBLIC_CREDITS_STARTER_AMOUNT   — Credits awarded (default: 50)
//   NEXT_PUBLIC_CREDITS_STANDARD_AMOUNT  — Credits awarded (default: 150)
//   NEXT_PUBLIC_CREDITS_PRO_AMOUNT       — Credits awarded (default: 500)

export interface CreditBundle {
  id: string
  name: string
  priceId: string
  credits: number
  displayPrice: string
  description: string
  popular?: boolean
}

export const CREDIT_BUNDLES: CreditBundle[] = [
  {
    id: 'starter',
    name: 'Starter',
    priceId: process.env.NEXT_PUBLIC_STRIPE_CREDITS_STARTER ?? '',
    credits: parseInt(process.env.NEXT_PUBLIC_CREDITS_STARTER_AMOUNT ?? '50'),
    displayPrice: '$9',
    description: 'Great for a focused job search',
  },
  {
    id: 'standard',
    name: 'Standard',
    priceId: process.env.NEXT_PUBLIC_STRIPE_CREDITS_STANDARD ?? '',
    credits: parseInt(process.env.NEXT_PUBLIC_CREDITS_STANDARD_AMOUNT ?? '150'),
    displayPrice: '$19',
    description: 'Most popular — covers a full job hunt',
    popular: true,
  },
  {
    id: 'pro',
    name: 'Pro',
    priceId: process.env.NEXT_PUBLIC_STRIPE_CREDITS_PRO ?? '',
    credits: parseInt(process.env.NEXT_PUBLIC_CREDITS_PRO_AMOUNT ?? '500'),
    displayPrice: '$49',
    description: 'For power users or recruiters',
  },
]

// Map from Stripe Price ID → credit amount.
// Used server-side in the webhook to know how many credits to award.
export const PRICE_ID_TO_CREDITS: Record<string, number> = Object.fromEntries(
  CREDIT_BUNDLES
    .filter((b) => b.priceId)
    .map((b) => [b.priceId, b.credits])
)

// How many credits each action costs.
// Change these values to reprice actions without touching any other code.
export const CREDIT_COSTS = {
  TAILORED_RESUME: 10,
  COVER_LETTER: 5,
  AI_CHAT_MESSAGE: 1,
  ATS_SCORE: 3,
  INTERVIEW_PREP: 5,
} as const

export type CreditAction = keyof typeof CREDIT_COSTS
