'use server'

import { createClient, createServiceClient } from '@/utils/supabase/server'
import { CREDIT_COSTS, type CreditAction } from '@/lib/stripe/credit-bundles'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface CreditLedgerEntry {
  id: string
  user_id: string
  amount: number
  action: string
  reference_id: string | null
  description: string | null
  created_at: string
}

export interface CreditBalanceResult {
  balance: number
}

export interface DeductCreditsResult {
  success: boolean
  balance: number      // balance after the attempted operation
  error?: 'insufficient_credits' | 'user_not_found'
}

// ---------------------------------------------------------------------------
// Read balance
// ---------------------------------------------------------------------------

/**
 * Returns the current credit balance for the authenticated user.
 * Uses the credit_balance view (SUM of all ledger entries).
 */
export async function getUserCreditBalance(): Promise<number> {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const { data, error } = await supabase
    .from('credit_balance')
    .select('balance')
    .eq('user_id', user.id)
    .maybeSingle()

  if (error) throw error
  return data?.balance ?? 0
}

/**
 * Returns the credit balance for any user by ID.
 * Requires service role — for admin and server-side use only.
 */
export async function getUserCreditBalanceById(userId: string): Promise<number> {
  const supabase = await createServiceClient()

  const { data, error } = await supabase
    .from('credit_balance')
    .select('balance')
    .eq('user_id', userId)
    .maybeSingle()

  if (error) throw error
  return data?.balance ?? 0
}

// ---------------------------------------------------------------------------
// Deduct credits (server-side, called before every AI action)
// ---------------------------------------------------------------------------

/**
 * Checks the user's balance and deducts credits atomically.
 * Returns { success: false } if insufficient credits — caller should abort
 * the action and show a "buy credits" prompt.
 *
 * @param userId      - The user's UUID
 * @param action      - One of the CREDIT_COSTS keys
 * @param referenceId - Optional: resume ID, job ID, etc. for audit trail
 */
export async function deductCredits(
  userId: string,
  action: CreditAction,
  referenceId?: string
): Promise<DeductCreditsResult> {
  const supabase = await createServiceClient()
  const cost = CREDIT_COSTS[action]

  // Read current balance
  const { data: balanceRow } = await supabase
    .from('credit_balance')
    .select('balance')
    .eq('user_id', userId)
    .maybeSingle()

  const currentBalance = balanceRow?.balance ?? 0

  if (currentBalance < cost) {
    return { success: false, balance: currentBalance, error: 'insufficient_credits' }
  }

  // Insert negative ledger entry
  const { error } = await supabase.from('credit_ledger').insert({
    user_id: userId,
    amount: -cost,
    action: action.toLowerCase().replace(/_/g, '_') as string,
    reference_id: referenceId ?? null,
    description: `Used ${cost} credit${cost === 1 ? '' : 's'} for ${action.toLowerCase().replace(/_/g, ' ')}`,
  })

  if (error) throw error

  return { success: true, balance: currentBalance - cost }
}

// ---------------------------------------------------------------------------
// Add credits (server-side, called from webhook after purchase)
// ---------------------------------------------------------------------------

/**
 * Adds credits to a user's account.
 * Only call this from trusted server-side code (webhooks, admin actions).
 *
 * @param userId      - The user's UUID
 * @param amount      - Positive integer of credits to add
 * @param action      - Ledger action label
 * @param referenceId - Optional: Stripe payment_intent ID, etc.
 * @param description - Optional: human-readable note
 */
export async function addCredits(
  userId: string,
  amount: number,
  action: 'purchase' | 'admin_adjustment' | 'refund' | 'welcome_bonus',
  referenceId?: string,
  description?: string
): Promise<{ newBalance: number }> {
  if (amount <= 0) throw new Error('Credit amount must be a positive integer')

  const supabase = await createServiceClient()

  await supabase.from('credit_ledger').insert({
    user_id: userId,
    amount,
    action,
    reference_id: referenceId ?? null,
    description: description ?? `Added ${amount} credits`,
  })

  const newBalance = await getUserCreditBalanceById(userId)
  return { newBalance }
}

// ---------------------------------------------------------------------------
// Refund credits (called when an AI action fails after deduction)
// ---------------------------------------------------------------------------

/**
 * Refunds credits that were deducted for a failed action.
 * Links to the original deduction via referenceId for audit trail.
 */
export async function refundCredits(
  userId: string,
  action: CreditAction,
  referenceId?: string
): Promise<void> {
  const supabase = await createServiceClient()
  const cost = CREDIT_COSTS[action]

  await supabase.from('credit_ledger').insert({
    user_id: userId,
    amount: cost,
    action: 'refund',
    reference_id: referenceId ?? null,
    description: `Refund for failed ${action.toLowerCase().replace(/_/g, ' ')}`,
  })
}

// ---------------------------------------------------------------------------
// Credit history (for the user-facing ledger page)
// ---------------------------------------------------------------------------

/**
 * Returns paginated credit history for the authenticated user.
 */
export async function getCreditHistory(
  page = 1,
  pageSize = 20
): Promise<{ entries: CreditLedgerEntry[]; total: number }> {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')

  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  const { data, error, count } = await supabase
    .from('credit_ledger')
    .select('*', { count: 'exact' })
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .range(from, to)

  if (error) throw error

  return {
    entries: (data ?? []) as CreditLedgerEntry[],
    total: count ?? 0,
  }
}

// ---------------------------------------------------------------------------
// Guard helper — use this at the top of every credit-consuming server action
// ---------------------------------------------------------------------------

/**
 * Checks if the authenticated user can afford an action.
 * Throws an error if not authenticated.
 * Returns the current balance — does NOT deduct anything.
 *
 * Usage:
 *   const { canAfford, balance } = await canAffordAction('TAILORED_RESUME')
 *   if (!canAfford) redirect('/credits')
 */
export async function canAffordAction(
  action: CreditAction
): Promise<{ canAfford: boolean; balance: number; cost: number }> {
  const balance = await getUserCreditBalance()
  const cost = CREDIT_COSTS[action]
  return { canAfford: balance >= cost, balance, cost }
}
