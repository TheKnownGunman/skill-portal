"use server";

import { Stripe } from "stripe";
import { checkAuth } from "@/app/auth/login/actions";
import { createOrRetrieveCustomer } from "@/utils/actions/stripe/actions";
import { CREDIT_BUNDLES } from "@/lib/stripe/credit-bundles";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getStripe(): Stripe {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new Error("STRIPE_SECRET_KEY is not configured.");
  }
  return new Stripe(process.env.STRIPE_SECRET_KEY, {
    apiVersion: "2025-04-30.basil",
  });
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type StripeSessionResult =
  | { kind: "checkout"; clientSecret: string }
  | { kind: "error"; message: string };

// ---------------------------------------------------------------------------
// Credit purchase checkout session
// ---------------------------------------------------------------------------

/**
 * Creates a one-time payment Stripe Checkout session for a credit bundle.
 * The webhook (checkout.session.completed) adds credits once payment succeeds.
 *
 * @param priceId — One of the NEXT_PUBLIC_STRIPE_CREDITS_* price IDs
 */
export const createCreditPurchaseSession = async (
  priceId: string
): Promise<StripeSessionResult> => {
  const { authenticated, user } = await checkAuth();

  if (!authenticated || !user?.id || !user?.email) {
    return { kind: "error", message: "You must be signed in to purchase credits." };
  }

  // Validate the price ID belongs to a known bundle
  const bundle = CREDIT_BUNDLES.find((b) => b.priceId === priceId);
  if (!bundle) {
    return {
      kind: "error",
      message: "Unknown credit bundle. Please choose a valid package.",
    };
  }

  try {
    const stripe = getStripe();

    const customerId = await createOrRetrieveCustomer({
      uuid: user.id,
      email: user.email,
    });

    const returnUrl = `${process.env.NEXT_PUBLIC_SITE_URL}/credits/success?session_id={CHECKOUT_SESSION_ID}`;

    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      ui_mode: "embedded",
      mode: "payment",                       // one-time payment, not subscription
      line_items: [{ price: priceId, quantity: 1 }],
      allow_promotion_codes: true,
      return_url: returnUrl,
      client_reference_id: user.id,
      metadata: {
        userId: user.id,
        bundleId: bundle.id,
        credits: bundle.credits.toString(),
      },
    });

    if (!session.client_secret) {
      throw new Error("Failed to create Stripe session — no client secret returned.");
    }

    return { kind: "checkout", clientSecret: session.client_secret };
  } catch (error) {
    console.error("Error creating credit purchase session:", error);
    return {
      kind: "error",
      message: error instanceof Error ? error.message : "Failed to create checkout session.",
    };
  }
};

// ---------------------------------------------------------------------------
// Billing portal (manage payment methods, download invoices)
// ---------------------------------------------------------------------------

export const createPortalSession = async (): Promise<{ url: string }> => {
  const { authenticated, user } = await checkAuth();

  if (!authenticated || !user?.id || !user?.email) {
    throw new Error("User must be authenticated to access the billing portal.");
  }

  const stripe = getStripe();

  const customerId = await createOrRetrieveCustomer({
    uuid: user.id,
    email: user.email,
  });

  const portalSession = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: `${process.env.NEXT_PUBLIC_SITE_URL}/credits`,
  });

  return { url: portalSession.url };
};
