// src/app/checkout-return/route.ts

import { redirect } from "next/navigation";
import { NextRequest } from "next/server";
import Stripe from "stripe";


export const GET = async (request: NextRequest) => {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
  const { searchParams } = new URL(request.url);

  const stripeSessionId = searchParams.get("session_id");


  if (!stripeSessionId?.length)
    return redirect("/home");

  const session = await stripe.checkout.sessions.retrieve(stripeSessionId);

  if (session.status === "complete") {
    return redirect(`/subscription/checkout/success?session_id=${stripeSessionId}`);
  }

  if (session.status === "open") {
    const trialParam = session.metadata?.include_trial === "true" ? "&trial=true" : "";

    return redirect(
      `/subscription/checkout?price_id=${session.metadata?.price_id}${trialParam}`,
    );
  }

  return redirect("/home");
};
