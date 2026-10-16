# Observability Philosophy

Observability is NOT optional.

This is a micro SaaS.

Profitability visibility is mandatory.

The founder must always know:

- how much revenue is generated
- how much AI costs
- how much Deepgram costs
- gross margin per user
- heavy users
- failing jobs
- queue health
- conversion rates

Never build features without instrumentation.

Every external provider call must be measurable.

---

# Cost Tracking Rules

Every provider interaction MUST be recorded.

Track costs for:

- Deepgram
- LLM formatting
- WhatsApp provider (if applicable)
- storage
- future providers

Never estimate blindly.

Always store actual measured usage.

Required metrics:

```ruby
provider
operation_type
input_units
output_units
duration_ms
cost_in_cents
success
error_code
```

Examples:

```ruby
deepgram_transcription
llm_formatting
whatsapp_message_send
```

All provider calls should be traceable.

---

# Usage Tracking

Every meaningful product action should generate usage events.

Track:

- whatsapp connected
- whatsapp disconnected
- audio intercepted
- audio transcribed
- ai formatting executed
- transcription delivered
- billing activated
- quota exceeded
- onboarding completed

Good:

```ruby
UsageEvent.create!(
  user:,
  event_type: :audio_transcribed
)
```

Avoid analytics abstraction layers.

Simple database events first.

---

# Plans

The product currently supports:

## Free

- 20 transcriptions per month
- Deepgram transcription
- lightweight branding
- no AI formatting
- standard queue priority

## Basic

Price:

```txt
R$5,99/month
```

Features:

- 500 transcriptions per month
- no AI formatting
- no branding
- higher queue priority

## Pro

Price:

```txt
R$19,90/month
```

Features:

- 2,000 transcriptions per month
- AI formatting
- formatting modes
- no branding
- highest queue priority

---

# Quota Philosophy

Quotas MUST be enforced.

Never trust frontend validation.

Validate server-side.

Quota check occurs BEFORE:

1. transcription
2. AI formatting
3. WhatsApp sending

Users exceeding quota should receive a clear message.

Example:

```txt
Você atingiu o limite do seu plano.
Faça upgrade para continuar usando.
```

Do not silently fail.

---

# Billing

Billing provider:

Banco Inter (Pix Automático, via `Inter::PixService`).

Keep billing simple.

Required entities:

```ruby
Subscription
Plan
Invoice
Payment
```

Subscription states:

```ruby
inactive
trialing
active
past_due
cancelled
expired
```

Webhooks MUST be idempotent.

Never trust webhook ordering.

Store raw webhook payloads.

Required:

```ruby
WebhookEvent
```

with:

```ruby
provider
external_id
payload
processed_at
status
```

---

# WhatsApp Provider Rules

The WhatsApp provider already exists externally.

Treat it as an adapter.

Never couple business logic directly to provider implementation.

Preferred interface:

```ruby
WhatsappProvider.connect_session
WhatsappProvider.disconnect
WhatsappProvider.send_reply
WhatsappProvider.fetch_contacts
```

Controllers should never directly call external APIs.

Use thin adapters.

Always handle provider failures gracefully.

Never crash the pipeline.

---

# Audio Pipeline

Pipeline flow:

```txt
WhatsApp webhook
    ↓
Validate contact rule
    ↓
Validate quota
    ↓
Download audio
    ↓
Deepgram transcription
    ↓
Optional LLM formatting
    ↓
Send WhatsApp reply
    ↓
Track costs
    ↓
Track usage
```

Pipeline must be async.

Never block requests.

Use jobs.

---

# Retry Philosophy

External integrations fail.

Retries are mandatory.

Retry:

- Deepgram failures
- WhatsApp provider failures
- LLM failures
- billing webhooks

Prefer exponential backoff.

Failures must be observable.

Never retry forever.

Store last error.

Example:

```ruby
failure_reason
failure_at
retry_count
```

---

# State Machines

Prefer enums over state machine gems.

Example:

```ruby
enum status: {
  pending: 0,
  processing: 1,
  completed: 2,
  failed: 3
}
```

Avoid adding gems for this.

Rails enums are enough.

---

# Suggested Core Models

Expected models include:

```ruby
User

WhatsappAccount
WhatsappSessionEvent

WhatsappContact
ContactRule

AudioMessage
Transcription

AiFormatting

UsageEvent
ProviderUsage

Subscription
Plan
Invoice
Payment

WebhookEvent
```

Keep models explicit.

Avoid hidden behavior.

---

# Suggested Associations

Example:

```ruby
User
  has_one :whatsapp_account
  has_many :contact_rules
  has_many :audio_messages
  has_many :transcriptions
  has_one :subscription
```

```ruby
AudioMessage
  belongs_to :user
  belongs_to :contact_rule

  has_one :transcription
```

```ruby
Transcription
  belongs_to :audio_message
```

---

# Admin Philosophy

Admin is a business cockpit.

Primary goal:

make the business observable.

Admin dashboard should prioritize:

## Revenue

- MRR
- active subscriptions
- conversion
- churn

## Usage

- transcriptions today
- active users
- top users
- heavy users

## Costs

- Deepgram cost
- LLM cost
- cost per user
- margin estimate

## Reliability

- failed jobs
- queue latency
- webhook failures
- provider failures

Prefer dense admin screens.

Tables are encouraged.

---

# User Experience Philosophy

The app should disappear after setup.

Ideal flow:

```txt
Sign up
    ↓
Connect WhatsApp
    ↓
Choose contacts
    ↓
Done
```

The user should rarely open the app again.

This is a utility product.

Avoid unnecessary engagement mechanics.

No gamification.

No badges.

No fake achievements.

---

# Loading States

Every async interaction must provide feedback.

Prefer:

- skeletons
- disabled buttons
- loading indicators
- optimistic UI when safe

Never leave users guessing.

---

# Empty States

Always include useful empty states.

Example:

No contacts selected:

```txt
Selecione os contatos que você quer transcrever.
```

No WhatsApp connected:

```txt
Conecte seu WhatsApp para começar.
```

Avoid blank screens.

---

# Accessibility

Always include:

- labels
- keyboard support
- focus states
- aria labels

Interactive elements must be accessible.

---

# Performance Rules

Avoid N+1 queries.

Use:

```ruby
includes
preload
eager_load
```

Prefer pagination.

Use Pagy.

Avoid loading huge datasets.

Heavy analytics should be aggregated.

Do not compute expensive metrics in views.

---

# Security

Never trust webhook payloads.

Validate signatures when supported.

Users must only access owned resources.

Never expose provider secrets.

Never log sensitive credentials.

Encrypt sensitive tokens.

Prefer Rails encrypted attributes.

---

# Logging Rules

Logs should be useful.

Good:

```ruby
Rails.logger.info(
  event: "transcription_completed",
  user_id: user.id,
  audio_message_id: audio.id,
  duration_ms: duration
)
```

Bad:

```ruby
puts "working"
```

Avoid noisy logs.

Prefer structured logs.

---

# Code Style

Prefer:

```ruby
redirect_to ..., notice:
redirect_to ..., alert:
```

Prefer readable code.

Avoid cleverness.

Avoid deep abstractions.

Prefer boring maintainable Rails.

Always ask:

> Is this the simplest implementation that works?

---

# Important Rule

EscreveZap is a utility SaaS.

Speed of shipping matters more than perfect architecture.

Prefer:

- simple
- maintainable
- observable
- profitable

over

- elegant
- over-engineered
- theoretical

The founder should be able to understand every part of the codebase.

Favor pragmatism.