# SchoolFlow student virtual-account payments

Status: proposed architecture; no live payment configuration or production database changes.

## Decision

Build a provider-neutral payment layer with Paystack Dedicated Virtual Accounts (DVA) as the first provider. Assign one persistent virtual account to each student, scoped to one school and one payment-provider merchant account. The system must support two merchant ownership modes without changing the parent or finance ledger workflows:

- `platform_managed`: Mento's approved Paystack integration creates student DVAs. Each school is represented by an approved Paystack subaccount or split destination so settlement is routed to that school's verified bank account. This requires Paystack's B2B2C approval and written confirmation of the settlement model.
- `school_managed`: the school connects its own approved Paystack merchant account and settlement bank account. DVAs are created under that merchant integration. Credentials are encrypted server-side and never returned to the browser.

A school may only use one active ownership mode at a time. Configuration begins in `pending_review`; payments stay disabled until merchant ownership, settlement destination, webhook, and test payment have been verified. Do not silently default to Mento's settlement account.

## Provider constraints to verify with Paystack

- DVA availability is for eligible, registered Nigerian businesses that have completed Paystack go-live.
- DVA creation is asynchronous; handle assignment success/failure events and do not show an account as ready until confirmed.
- `charge.success` is the payment notification for successful incoming DVA transfers. Verify webhook signatures and re-query the transaction with Paystack before posting.
- Paystack documents B2B2C account naming for platforms providing virtual accounts to schools; obtain approval before using school/student account-name formatting.
- Paystack documents attaching a subaccount or split code to a DVA. Confirm eligibility, settlement timing, fees, reversals, and whether the intended school settlement arrangement is approved for this use case.
- DVA account limits and pricing are provider-controlled and may change. Handle limits and provider errors without creating duplicate accounts.

References:
- https://paystack.com/docs/payments/dedicated-virtual-accounts/
- https://paystack.com/docs/api/dedicated-virtual-account/
- https://paystack.com/docs/api/subaccount/

## Data model proposal

All records carry `school_id`; foreign keys should enforce that student, fee record, payment account, and payment belong to the same school.

### `school_payment_settings`
One row per school/provider configuration:
- `id`, `school_id`, `provider` (initially `paystack`)
- `ownership_mode` (`platform_managed` | `school_managed`)
- `status` (`not_configured` | `pending_review` | `test_required` | `active` | `suspended`)
- `provider_account_code` (non-secret merchant/subaccount identifier)
- `settlement_beneficiary_label` (display-safe name; no full bank details)
- `currency_code`, `approved_at`, `created_at`, `updated_at`
- encrypted credential reference only when school-managed; never store a raw secret key in a public table.

### `student_payment_accounts`
- `id`, `school_id`, `student_id`, `provider`, `provider_account_id`
- `provider_customer_code`, `account_name`, `account_number`, `bank_name`, `currency_code`
- `status` (`requested` | `pending` | `active` | `failed` | `suspended`)
- `provider_metadata` (allowlisted non-sensitive fields only), timestamps
- Unique active account per `(school_id, student_id, provider)`; unique provider account number within its merchant scope.
- Do not delete/reassign an account when a student changes class or guardian. Preserve historical ownership and support controlled deactivation.

### `school_payment_events`
Immutable provider event inbox:
- `id`, `school_id`, `provider`, `provider_account_id`, `event_type`
- `provider_event_id` / transaction reference, `payload_hash`, minimal redacted payload, `received_at`, `processed_at`
- `processing_status` (`received` | `verified` | `posted` | `ignored` | `failed` | `needs_review`), `failure_code`
- Unique idempotency key on provider + merchant scope + provider transaction reference/event identifier.
- Never trust `school_id`, `student_id`, amount, or account mapping supplied by browser metadata. Resolve them from the stored virtual-account mapping and verified provider transaction.

### Ledger linkage
Extend the existing `school_fee_payments` ledger with nullable provider metadata such as `provider`, `provider_reference`, `payment_source`, and `provider_event_id`. Keep existing manual receipt workflow intact. Enforce uniqueness for provider transaction references. Preserve the existing fee-record and school relationships and existing finance audit trail.

## Server-side components

1. `payment-admin` Edge Function: authenticated admin-only actions to start/refresh school payment setup and request student account assignment. Derive school and role from the verified Supabase JWT/profile; never accept a client-supplied school ID as authorization.
2. `paystack-webhook` Edge Function: public webhook endpoint with JWT verification disabled only because Paystack cannot provide a Supabase user JWT. Verify Paystack's HMAC SHA-512 signature against the raw request body using the correct merchant secret; resolve merchant configuration from a trusted endpoint/secret mapping; insert the event inbox row idempotently; return promptly.
3. `payment-event-processor`: server-only processor to re-query/verify provider transaction status, currency, amount, reference, receiving account, merchant scope and successful status. Resolve the student from `student_payment_accounts`, then resolve the current eligible fee record. Post through a dedicated server-only database routine that writes the existing fee ledger and audit log atomically.
4. `payment-account-reconcile`: admin-triggered or scheduled reconciliation for account-assignment events and missing webhook events. Respect Paystack's requery rate limits.

Never place Paystack secret keys in `src/portal.js`, `src/parent.js`, HTML, browser local storage, or client-callable database rows. Use Supabase Edge Function secrets for Mento's integration. For school-managed credentials, use an encrypted secret store with strict service-role-only access and key rotation; do not store plaintext API keys in normal tables.

## Parent and admin experience

Parent portal:
- Show a student's account only after provider assignment is confirmed.
- Display bank, account name, account number, school name, and clear transfer instructions.
- Explain that the account is dedicated to that student and should not be reused for another child.
- Show pending/confirmed/reversed payments and downloadable/printable receipts.
- Keep existing fee balances visible when online payments are not configured.

Admin finance:
- New Payment settings section shows ownership mode, provider status, settlement beneficiary, test status and last webhook health.
- Account assignment status per student, retry action, and safe error messages.
- Reconciliation view for unmatched, duplicate, delayed, reversed, and overpayment events.
- No manual ability to mark a provider transaction as verified without an auditable override reason and finance permission.

## Payment posting rules

- Only verified provider-side successful transactions may post automatically.
- Use integer minor units (kobo) for provider amount comparisons; convert carefully to the existing numeric naira ledger.
- Match exact provider merchant scope + receiving virtual account + currency + reference.
- Idempotency is mandatory; webhook retries must not create duplicate receipts.
- Partial payments are allowed if the existing fee ledger supports them; allocate to the selected/current fee record under an explicit policy. Do not silently spread a payment across terms.
- Overpayments, unknown accounts, wrong currency, duplicate references, missing fee records, and reversals go to `needs_review`; do not silently credit balances.
- Keep an immutable event record and an audit entry for every posting, ignore, manual resolution, or reversal.
- A reversal must create a compensating ledger action; never delete the original receipt.
- Webhook processing must be atomic for event state + ledger posting, with retry-safe locking.

## Rollout plan

### Phase 0 — Provider approval and sandbox readiness
- Ask Paystack to approve the B2B2C school-platform use case and confirm the exact settlement structure for both ownership modes.
- Confirm business category, KYC requirements, account naming, account limits, fees, settlement timing, refunds/reversals and support process.
- Obtain test credentials via secure environment configuration. No live keys in chat or GitHub.

### Phase 1 — Schema and server foundations
- Add additive migrations only; no destructive edits to existing finance tables or Jane's records.
- Add payment settings, student account mapping and event inbox tables with tenant-scoped RLS.
- Add service-only atomic posting routine and audit integration.
- Deploy Edge Functions to staging only and verify signature, idempotency, cross-school isolation and replay handling.

### Phase 2 — Sandbox UI and test transactions
- Admin setup wizard with ownership mode selection, settlement destination confirmation and test status.
- Assign test DVAs to test students; show account details in parent portal.
- Test full, partial, duplicate, delayed, wrong-account, wrong-currency, overpayment and reversed payment cases.
- Confirm existing manual receipts and parent fee views remain unchanged.

### Phase 3 — Controlled production pilot
- Only after written Paystack approval and successful staging tests, configure one pilot school.
- Use a verified settlement destination and low-value real transfer.
- Monitor reconciliation, settlement and receipts before enabling additional schools.
- Production schema migration, secrets, function deployment and frontend release require explicit production rollout approval.

## Explicit non-goals for first release

- No card checkout, wallet, automatic salary payouts, multi-school pooled wallet, or Mento custody of school funds.
- No parent-submitted transfer reference treated as proof of payment.
- No automatic production enablement before Paystack approval and a verified settlement test.
