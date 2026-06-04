# Monetisation & Billing

## Current System

The app currently uses a **subscription model** (free vs pro) managed through Stripe. Users pay a recurring monthly/annual fee for unlimited resumes and model access. The relevant files are:

- `src/utils/actions/stripe/actions.ts` — customer creation, subscription sync
- `src/app/api/webhooks/stripe/route.ts` — webhook handler
- `src/lib/stripe/subscription-sync.ts` — maps Stripe data to the database
- `src/lib/subscription-access.ts` — determines what a user can access
- `src/lib/resume-limits.ts` — enforces resume creation quotas

---

## Proposed System: Credits / Tokens

Instead of a subscription, users buy a bundle of credits upfront and spend them on actions (generating a tailored CV, applying to a job, etc.). This is a **pay-as-you-go** model.

### Why this is better for your value proposition

- A subscription implies ongoing value. A credit model fits better when the core action is discrete: "I need 5 tailored CVs this month."
- Credits lower the barrier to try the product — no recurring commitment.
- You can price premium actions (e.g. a cover letter, a LinkedIn rewrite) at higher credit costs without changing the base price.

---

## Credit System Design

### Credit Costs (suggested starting point)

| Action | Credits |
|---|---|
| Generate tailored CV | 10 |
| Generate cover letter | 5 |
| AI resume chat message | 1 |
| ATS score analysis | 3 |
| Job application submission (future) | 2 |

### Credit Bundles (Stripe one-time payments)

| Bundle | Credits | Price |
|---|---|---|
| Starter | 50 | $9 |
| Standard | 150 | $19 |
| Pro | 500 | $49 |

Stripe supports one-time payments via **Payment Links** or **Checkout Sessions** in `payment` mode (not `subscription` mode). This is simpler than the current setup.

---

## Database Changes Required

### New table: `credit_ledger`

```sql
CREATE TABLE public.credit_ledger (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id uuid NOT NULL,
  amount integer NOT NULL,           -- positive = purchase, negative = spend
  action text NOT NULL,              -- 'purchase', 'tailored_resume', 'cover_letter', etc.
  reference_id text,                 -- stripe payment intent id or resume id
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.credit_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY credit_ledger_policy ON public.credit_ledger
  USING (user_id = auth.uid());
GRANT ALL ON public.credit_ledger TO authenticated;
GRANT ALL ON public.credit_ledger TO service_role;
```

**The user's balance is always computed as:**
```sql
SELECT COALESCE(SUM(amount), 0) AS balance
FROM public.credit_ledger
WHERE user_id = $1;
```

Never store a balance field directly — the ledger is the source of truth and is auditable.

### Remove or repurpose `subscriptions` table

The existing `subscriptions` table can remain for users who were on the old plan but is no longer the primary gating mechanism. Feature access is gated by credit balance instead.

---

## Stripe Integration Changes

### Switch from subscription to one-time payment

In `src/utils/actions/stripe/actions.ts`, replace the current `postStripeSession()` which creates a subscription checkout with a one-time payment checkout:

```typescript
// New: one-time credit purchase
export async function createCreditPurchaseSession(
  userId: string,
  priceId: string  // Stripe Price ID for the credit bundle
) {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
  const customer = await createOrRetrieveCustomer(userId);

  return stripe.checkout.sessions.create({
    mode: 'payment',                           // not 'subscription'
    customer: customer.stripeCustomerId,
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NEXT_PUBLIC_SITE_URL}/subscription/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_SITE_URL}/subscription`,
    metadata: { userId },
  });
}
```

### Stripe Price IDs to create in your Stripe dashboard

Create three **one-time prices** (not recurring) on a product called "Credits":

```
NEXT_PUBLIC_STRIPE_CREDITS_STARTER=price_xxx   # $9 / 50 credits
NEXT_PUBLIC_STRIPE_CREDITS_STANDARD=price_xxx  # $19 / 150 credits
NEXT_PUBLIC_STRIPE_CREDITS_PRO=price_xxx       # $49 / 500 credits
```

Map price IDs to credit amounts in `src/lib/stripe/credit-bundles.ts`:

```typescript
export const CREDIT_BUNDLES: Record<string, number> = {
  [process.env.NEXT_PUBLIC_STRIPE_CREDITS_STARTER!]: 50,
  [process.env.NEXT_PUBLIC_STRIPE_CREDITS_STANDARD!]: 150,
  [process.env.NEXT_PUBLIC_STRIPE_CREDITS_PRO!]: 500,
};
```

### Webhook changes

In `src/app/api/webhooks/stripe/route.ts`, handle `checkout.session.completed` for payment mode:

```typescript
case 'checkout.session.completed': {
  const session = event.data.object as Stripe.Checkout.Session;

  if (session.mode === 'payment') {
    const priceId = session.line_items?.data[0]?.price?.id;
    const creditsToAdd = CREDIT_BUNDLES[priceId ?? ''] ?? 0;

    await supabase.from('credit_ledger').insert({
      user_id: session.metadata?.userId,
      amount: creditsToAdd,
      action: 'purchase',
      reference_id: session.payment_intent as string,
    });
  }
  break;
}
```

---

## Deducting Credits on Actions

Wrap every credit-consuming action in a server action that checks balance first:

```typescript
// src/utils/actions/credits/actions.ts
export async function deductCredits(
  userId: string,
  amount: number,
  action: string,
  referenceId?: string
): Promise<{ success: boolean; newBalance: number }> {
  const supabase = await createServiceClient();

  // Read current balance
  const { data } = await supabase
    .from('credit_ledger')
    .select('amount')
    .eq('user_id', userId);

  const balance = data?.reduce((sum, row) => sum + row.amount, 0) ?? 0;

  if (balance < amount) {
    return { success: false, newBalance: balance };
  }

  await supabase.from('credit_ledger').insert({
    user_id: userId,
    amount: -amount,
    action,
    reference_id: referenceId,
  });

  return { success: true, newBalance: balance - amount };
}
```

Call `deductCredits()` before calling the AI in `tailorResume()`, `generateCoverLetter()`, etc.

---

## UI Changes Required

1. **Remove the "Upgrade to Pro" button** from `AppHeader` — replace with a **Credits balance chip** showing current balance.
2. **Add a "Buy Credits" page** at `/credits` with the three bundle options.
3. **Show credit cost** on each action button: "Generate CV (10 credits)".
4. **Low balance warning** when balance drops below 10 credits.
5. **Purchase confirmation** after Stripe checkout returns.

---

## Keeping Stripe vs Alternatives

Stripe is the right choice here. Alternatives:

| Option | Verdict |
|---|---|
| **Stripe** | Best — handles tax, fraud, international cards, webhooks |
| Paddle | Good for EU VAT handling, simpler but less flexible |
| Lemon Squeezy | Simpler API, good for indie products, less mature |
| PayPal | Poor developer experience, avoid |

Stick with Stripe. You are already integrated — it is a configuration change, not a rewrite.
