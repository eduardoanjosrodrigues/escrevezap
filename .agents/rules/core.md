# AGENTS.md — EscreveZap

AI coding instructions for the EscreveZap codebase.

EscreveZap is a WhatsApp audio transcription SaaS that connects to the user's own WhatsApp account and automatically transcribes selected voice messages directly inside the original WhatsApp conversation.

The application is a Rails monolith using Tailwind + Flowbite.

---

# Product Overview

EscreveZap automatically transcribes WhatsApp audio messages.

Users connect their own WhatsApp account using an unofficial WhatsApp provider (already implemented externally).

Users can configure which contacts should be monitored.

For each contact, users can choose:

- transcribe only my audios
- transcribe only the other person's audios
- transcribe both

When an audio message is intercepted:

1. Audio is downloaded
2. Audio is transcribed using Deepgram
3. Optional LLM formatting is applied
4. A reply message is sent to the original audio in WhatsApp
5. Usage and cost metrics are recorded

The product must feel magical and extremely low-friction.

The core value proposition is:

> Stop listening to long WhatsApp audios.

or

> Your WhatsApp now writes voice messages.

---

# Stack

| Layer                     | Tech                                 |
| ------------------------- | ------------------------------------ |
| Framework                 | Rails 8.x                            |
| Language                  | Ruby 3.x                             |
| Asset pipeline            | Propshaft                            |
| JS bundling               | jsbundling-rails                     |
| CSS bundling              | cssbundling-rails                    |
| CSS framework             | Tailwind CSS                         |
| UI components             | Flowbite                             |
| Frontend                  | Hotwire (Turbo + Stimulus)           |
| Authentication            | Devise                               |
| Background jobs           | SolidQueue                           |
| Realtime                  | ActionCable / SolidCable             |
| Cache                     | SolidCache                           |
| Uploads                   | Active Storage                       |
| Pagination                | Pagy                                 |
| Deployment                | Kamal + Docker                       |
| Speech-to-text            | Deepgram                             |
| Billing                   | Banco Inter (Pix Automático)         |
| Messaging Provider        | External WhatsApp provider           |

---

# Architecture Philosophy

This is a Rails monolith.

Always prefer:

- Rails conventions
- server-rendered HTML
- Turbo Frames
- Turbo Streams
- Stimulus
- background jobs
- POROs only when clearly useful
- simple controllers

Avoid:

- React
- Vue
- unnecessary APIs
- frontend state duplication
- GraphQL
- over-engineering
- service object explosion
- premature abstractions
- event sourcing
- CQRS
- unnecessary design patterns

Prefer boring Rails.

The application should remain maintainable by a solo founder.

If a feature can be implemented with conventional Rails CRUD, do that first.

---

# Product Architecture

The system is divided into:

1. Public marketing pages
2. User app (mobile-first)
3. Admin panel (desktop-only)
4. WhatsApp integration
5. Audio pipeline
6. Billing
7. Observability

---

# User Types

There are two user experiences.

## Administrators

Route prefix:

```ruby
/admin
```

Admin UI is desktop-first.

Requirements:

- optimized for 1280px+
- dense layouts are acceptable
- information-heavy interfaces
- dashboards
- filters
- tables
- metrics
- analytics
- observability

Prefer:

- sidebars
- tables
- cards
- charts
- admin productivity

Avoid oversized mobile spacing.

---

## Users

The customer experience is STRICTLY mobile-first.

Design for phones only.

Users primarily want:

1. connect WhatsApp
2. select contacts
3. forget the app exists

The app should feel like a native utility app.

Requirements:

- single-column layouts
- thumb-friendly interactions
- large tap targets
- low friction
- extremely clear UX

Avoid:

- sidebars
- enterprise dashboards
- complex navigation
- dense interfaces
- unnecessary text

---

# UI Philosophy

## Flowbite-first

Flowbite is the primary UI system.

Always prefer official Flowbite components before creating custom UI.

Use Flowbite for:

- navbar
- cards
- forms
- modals
- drawers
- tabs
- dropdowns
- accordions
- alerts
- badges
- pagination
- tables
- skeleton loading
- empty states

Before building custom markup, ask:

> Can this be built with Flowbite?

---

# Design Principles

The app should feel:

- calm
- modern
- simple
- premium
- fast
- trustworthy
- low-friction

Avoid:

- visual clutter
- enterprise styling
- noisy UI
- excessive borders
- dense mobile screens

Prefer:

- rounded corners
- generous spacing
- strong typography
- obvious actions
- simple onboarding

---

# Product Rules

Users connect THEIR OWN WhatsApp account.

This is not WhatsApp Business API.

Users authenticate using a QR code via the external WhatsApp provider.

Each user has:

```ruby
has_one :whatsapp_account
```

DO NOT model multiple WhatsApp accounts.

Assume:

```txt
1 user = 1 whatsapp account
```

Future scaling is not a concern right now.

Favor simplicity.

---

# Contact Rules

Users select contacts to monitor.

Each contact has independent settings.

Supported modes:

```ruby
only_me
only_them
both
```

Each contact may also configure:

```ruby
transcription_only
ai_formatted
```

AI formatting mode:

```ruby
faithful
organized
```

Definitions:

### faithful

Preserve the original speaking style.

Only improve:

- punctuation
- paragraph breaks
- readability
- minor grammar

Do not rewrite intent.

### organized

Rewrite into a clearer WhatsApp message.

Improve:

- structure
- clarity
- readability
- formatting

Preserve original meaning.

Never hallucinate information.

---

# WhatsApp Message Behavior

Transcriptions MUST be sent as a reply to the original audio message.

Never send standalone messages.

The response should feel native.

Example:

Audio message
↳ transcription reply

This is mandatory.

---

# Branding Rules

Free plan only:

append lightweight branding.

Example:

---
via EscreveZap

Paid plans:

NO branding.

Never inject marketing copy inside conversations.

Never make the WhatsApp output spammy.

---

# Routing Philosophy

Separate responsibilities clearly.

Example:

```ruby
authenticated :user do
  root "dashboard#index"

  resource :onboarding
  resource :whatsapp_connection

  resources :contacts
  resources :subscriptions
  resources :settings
end

namespace :admin do
  root "dashboard#index"
end
```

Rules:

- admin under `/admin`
- user app simple
- avoid deep nesting
- RESTful routes first

---

# Frontend Rules

Use:

- Turbo Drive
- Turbo Frames
- Turbo Streams
- Stimulus

Prefer server-rendered interactions.

Avoid SPA behavior.

Use Stimulus only for:

- QR polling
- timers
- copy interactions
- onboarding helpers
- realtime connection status

Do not build frontend state machines.

Server state is the source of truth.

---

# Tailwind Rules

Prefer semantic utility composition.

Good:

```html
p-4 rounded-xl max-w-md
```

Bad:

```html
p-[17px] rounded-[23px]
```

Avoid arbitrary values.

Use Tailwind spacing scale.

Prefer:

```html
gap-4
p-6
rounded-xl
text-sm
```

Consistency matters.

---

# Internationalization

Never hardcode user-facing strings.

Always use I18n.

Example:

```ruby
t(".title")
t("shared.save")
```

Primary language is Portuguese (Brazil).

Structure translations cleanly.

Example:

```yaml
pt-BR:
  onboarding:
    title:
```

---

# Authentication

Use Devise.

Keep authentication simple.

Required:

- email
- password
- password reset

Avoid social login initially.

Optimize for speed of implementation.

---

# Authorization

Keep authorization simple.

Users can only access their own resources.

Admin-only features belong under `/admin`.

Prefer controller-level authorization.

Avoid overcomplicated permission systems.

No RBAC.

No policy explosion.

---

# Database Philosophy

Favor relational integrity.

Use foreign keys.

Use database indexes.

Prefer enums for stable states.

Use nullable fields sparingly.

Always think about observability.

Every important operation should be traceable.

Avoid JSON columns unless flexibility is truly required.

Prefer explicit schema.

---

# Naming Conventions

Use boring Rails naming.

Good:

```ruby
Transcription
AudioMessage
WhatsappAccount
ContactRule
UsageEvent
```

Bad:

```ruby
AudioProcessingEngine
WhatsappPipelineOrchestrator
AIExecutionCoordinator
```

Prefer clarity over cleverness.

---

# Service Objects

Avoid service object explosion.

DO NOT create service objects for simple CRUD.

Allowed:

- provider adapters
- complex workflows
- external integrations

Good examples:

```ruby
DeepgramTranscriber
WhatsappProvider
LlmFormatter
Inter::PixService
```

Bad examples:

```ruby
CreateUserService
UpdateContactService
DashboardPresenter
```

Prefer model methods and controllers first.

---

# Background Jobs

Heavy work MUST be async.

Required background jobs:

- audio transcription
- AI formatting
- WhatsApp delivery
- billing webhooks
- retry jobs
- analytics aggregation

Keep jobs focused.

Good:

```ruby
TranscribeAudioJob
FormatTranscriptionJob
SendWhatsappReplyJob
```

Avoid giant jobs.

Prefer composable pipelines.

---

# WhatsApp Formatting Rules

Always use single asterisks (`*`) instead of double asterisks (`**`) for bold emphasis in WhatsApp messages and chatbot copies. Double asterisks do not render as bold in WhatsApp clients.

Example:
- Good: `*bold text*`
- Bad: `**bold text**`