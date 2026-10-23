# JHOOMO
# JHOOMO — COMPLETE APP DEVELOPMENT MASTER DOCUMENT
## Product Requirements Document (PRD) + Technical Specification + Legal & Compliance Checklist

**Product:** JHOOMO  
**Proposed Business/Trade Name:** JHOOMO EVENTS  
**Category:** Event Discovery, Ticket Booking & Organizer Management Platform  
**Reference Product:** BookMyShow-style event discovery and ticketing  
**Initial Launch Market:** Lucknow, Uttar Pradesh, India  
**Founder:** Shyam Chaturvedi  
**Technology & Development:** Ankit Jatav  
**Operations & Organizer Relations:** Gaurav Yadav  
**Business Structure at Launch:** Proposed sole proprietorship  
**Future Business Structure:** Jhoomo Private Limited, subject to a future decision  
**Proposed Future Equity Target:** Shyam 60%, Ankit 30%, Gaurav 10%. These are intended future ownership percentages, not currently issued shares.

---

# PART 1 — PRODUCT VISION

## 1.1 What is JHOOMO?

JHOOMO is an online platform where users discover events, buy tickets, receive digital QR tickets and manage their bookings. Event organizers can register, publish events, set ticket prices, monitor ticket sales and manage entry through QR scanning.

The product should support concerts, DJ nights, college festivals, workshops, comedy shows, cultural festivals, parties, meetups, networking events and other permitted events.

JHOOMO must provide three primary interfaces:

1. Customer Mobile App
2. Event Organizer Panel
3. Admin Dashboard

The product should be designed for future expansion across India, but the first release will focus on reliable operations in Lucknow.

## 1.2 Product principles

- Simple onboarding for customers and organizers.
- Fast event discovery and booking.
- Reliable payment verification.
- Unique, server-validated tickets.
- Transparent cancellation and refund conditions.
- Organizer verification and event moderation.
- Privacy-first user experience.
- Affordable infrastructure for an early-stage team.
- No fake booking confirmations or unverified payment claims.
- Modular architecture that can support future growth.

---

# PART 2 — USER APP: COMPLETE SCREEN REQUIREMENTS

## 2.1 Splash Screen

Display:
- JHOOMO logo.
- Brand tagline: “Discover Events. Book Your Moment.”
- Short loading animation.
- App version and connectivity handling.

The app should check the session and route users to onboarding or Home.

## 2.2 Onboarding Screens

Create three short introductory screens:

1. Discover events around you.
2. Book tickets in a few simple steps.
3. Keep your tickets and bookings in one place.

Provide Skip, Next and Get Started actions.

Location permission must be optional. Users who deny location permission must still be able to select their city manually.

## 2.3 Login and Registration

Support:
- Mobile number login.
- OTP verification through an approved SMS provider.
- Email login or verification if implemented.
- Terms and Privacy Policy links.
- Resend OTP with cooldown.
- Rate limiting and abuse protection.
- Logout and session management.

Do not collect unnecessary personal information during registration.

If users can browse public events without logging in, allow browsing before requiring authentication at checkout.

## 2.4 Home Screen

Design a modern event-discovery home screen inspired by the usability of major ticketing platforms, without copying their protected branding or assets.

Components:
- Header with JHOOMO logo.
- Selected city.
- Search bar.
- Notification icon.
- Promotional banner carousel.
- Featured events.
- Trending events.
- Events near the selected city.
- This weekend.
- Upcoming concerts and DJ nights.
- College and cultural events.
- Workshops and meetups.
- Recommended events.
- Recently viewed events.
- Bottom navigation.

Bottom navigation:
- Home
- Explore
- My Tickets
- Saved
- Profile

All event sections must load real backend data. Avoid permanently hardcoded demo cards in production.

## 2.5 City Selection

Features:
- Search city by name.
- Select Lucknow initially.
- Save selected city to the user profile.
- Change city at any time.
- Handle location permission gracefully.
- Do not expose a user's precise location to organizers unless genuinely required and separately authorized.

## 2.6 Search and Explore

Search by:
- Event name.
- Artist or performer.
- Venue.
- Organizer.
- Category.
- City.

Filters:
- Date.
- Today.
- Tomorrow.
- This weekend.
- Price range.
- Free or paid.
- Event category.
- Online or offline.
- Distance, only when location is available and permitted.

Include:
- Sort by date.
- Sort by relevance.
- Popularity-based ordering where justified.
- Empty results state.
- Search history controls.
- Clear filters.

## 2.7 Event Details Screen

Each event page must include:

- Cover image and gallery.
- Event title.
- Organizer name and verification status.
- Date and start/end time.
- Venue name and address.
- City.
- Event description.
- Category.
- Age restrictions.
- Entry rules.
- Accessibility information when supplied.
- Ticket categories and availability.
- Price and applicable fees.
- Booking deadline.
- Cancellation and refund terms.
- Event-specific instructions.
- Contact/help route.
- Share button.
- Save/favourite button.
- Report event option.

The displayed price and fees must match the checkout calculation.

Private event addresses must remain hidden from unauthorized users. Show the address only according to the organizer's privacy settings and the attendee's approved booking/RSVP status.

## 2.8 Ticket Selection

Organizers can configure ticket categories such as:
- General Admission.
- Early Bird.
- VIP.
- Couple Pass.
- Group Pass.
- Workshop Pass.

These are examples, not mandatory categories.

For every ticket category, store:
- Ticket name.
- Description.
- Price.
- Quantity available.
- Sales start/end time.
- Per-order minimum and maximum.
- Age or eligibility restrictions, if applicable.
- Refundability.
- Applicable taxes and fees.
- Sale status.

The server must enforce inventory limits and prevent overselling.

Do not trust prices or quantities sent only by the client app.

## 2.9 Checkout

Checkout must display:
- Event and ticket summary.
- Quantity.
- Base ticket amount.
- Applicable fees and taxes.
- Discount, if any.
- Total payable.
- Refund/cancellation summary.
- Customer contact details.
- Required acknowledgements.

Require explicit acceptance of applicable booking terms before payment.

Create a unique booking reference and payment order through the backend.

The booking must not become confirmed merely because the payment screen closes or the app receives a client-side success callback.

## 2.10 Payment Screen

Primary payment provider: Razorpay, subject to merchant approval.

Expected flow:
1. Backend creates a booking in a pending state.
2. Backend creates the corresponding payment order using the approved gateway integration.
3. Customer completes payment.
4. Backend verifies the payment using trusted gateway data.
5. Webhook events are signature-verified and processed idempotently.
6. Booking is confirmed only after successful verification and inventory validation.
7. QR ticket is generated for confirmed eligible tickets.
8. Receipt and confirmation notification are sent.

Handle:
- Successful payments.
- Failed payments.
- Cancelled checkout.
- Pending payments.
- Duplicate webhook delivery.
- Delayed payment confirmation.
- Payment success with booking-processing failure.
- Refund processing.
- Payment reconciliation.

Never store card numbers, CVV or other prohibited sensitive payment credentials in JHOOMO's database.

## 2.11 Booking Confirmation

Show:
- Booking ID.
- Event name.
- Event date/time.
- Ticket category.
- Number of tickets.
- Payment status.
- Booking status.
- QR ticket access.
- Downloadable receipt, where supported.
- Event instructions.
- Support link.

Provide:
- View Ticket.
- Add to Calendar.
- Share Event.
- Contact Support.

## 2.12 My Tickets / My Bookings

Tabs:
- Upcoming.
- Completed.
- Cancelled.
- Refunds.

Each booking must show its current status and provide appropriate actions.

Possible booking statuses:
- PENDING_PAYMENT
- CONFIRMED
- CANCEL_REQUESTED
- CANCELLED
- REFUND_PENDING
- PARTIALLY_REFUNDED
- REFUNDED
- PAYMENT_FAILED
- EXPIRED

The backend must control status transitions. Do not allow the client to mark a booking as paid or refunded.

## 2.13 Digital QR Ticket

Each ticket must have:
- Unique ticket identifier.
- Booking reference.
- Event reference.
- Ticket category.
- Validity status.
- QR code containing a signed or opaque ticket token, not unnecessary personal data.

The QR code must be validated against the backend.

Rules:
- One valid ticket can be checked in only once.
- Duplicate scans must be rejected.
- Cancelled, refunded or invalid tickets must be rejected according to event policy.
- Offline scanning, if introduced, must use a carefully designed synchronization and duplicate-prevention mechanism.

## 2.14 Saved Events

Users can:
- Save an event.
- Remove a saved event.
- View saved events.
- Receive optional reminders.
- Share an event.

Marketing notifications must respect user preferences.

## 2.15 Notifications

Support:
- Booking confirmation.
- Payment failure.
- Refund updates.
- Event reminder.
- Event time or venue changes.
- Event cancellation.
- Organizer announcements relevant to a booking.
- Security alerts.

Allow users to manage non-essential notification preferences.

## 2.16 Profile

Sections:
- Name.
- Profile photo, optional.
- Mobile number.
- Email.
- Selected city.
- Saved events.
- Booking history.
- Notification preferences.
- Privacy settings.
- Help and support.
- Terms and Conditions.
- Privacy Policy.
- Refund Policy.
- Delete Account.
- Logout.

Provide an account deletion request flow, subject to applicable legal record-retention requirements. Explain any information that must legally be retained.

---

# PART 3 — ORGANIZER PANEL

The organizer experience can initially be a responsive web application. A separate organizer mobile app can be introduced later if needed.

## 3.1 Organizer Registration

Collect only the information needed for onboarding and verification.

Possible fields:
- Full name.
- Mobile number.
- Email.
- Organizer/business name.
- Organizer type: Individual, Business, Organization or Other.
- Address.
- PAN or other tax details where required.
- Bank account and beneficiary details for approved settlements.
- Identity verification details where required.
- Business registration or GSTIN where applicable.
- Authorization to represent the organization.
- Agreement acceptance.

Verification requirements should be proportionate to the organizer type, event risk and payment provider's requirements.

Sensitive identity documents must be stored securely, access-restricted and retained only as permitted.

## 3.2 Organizer Dashboard

Display:
- Total published events.
- Upcoming events.
- Tickets sold.
- Available inventory.
- Gross ticket sales.
- Applicable fees.
- Refunds.
- Net payable amount, where settlement data is available.
- Settlement status.
- Attendee count.
- Recent bookings.

Use backend calculations and reconciled payment records for financial summaries.

## 3.3 Create Event Wizard

Use a multi-step form.

### Step 1: Basic Information
- Event title.
- Category.
- Description.
- Cover image.
- Gallery.
- Organizer details.

### Step 2: Date and Venue
- Event date.
- Start/end time.
- Venue name.
- Venue address.
- City.
- Online/offline format.
- Venue map link.
- Private address settings.
- Age restrictions.

### Step 3: Tickets
- Ticket category.
- Price.
- Quantity.
- Sale start/end.
- Minimum/maximum per booking.
- Taxes and fees.
- Refund rules.
- Ticket instructions.

### Step 4: Entry Rules
- Required ID, if applicable.
- Age verification, if applicable.
- Re-entry policy.
- Dress code, if applicable.
- Prohibited items.
- Accessibility details.

### Step 5: Event Permissions
Collect confirmations and documents appropriate to the event.

The organizer must confirm that the event is authorized, the listing is accurate and required venue/event permissions have been obtained.

### Step 6: Preview and Submit
Display the complete listing before submission.

Possible statuses:
- DRAFT
- SUBMITTED
- UNDER_REVIEW
- NEEDS_CHANGES
- APPROVED
- PUBLISHED
- REJECTED
- CANCELLED
- COMPLETED

Only authorized backend workflows can publish events.

## 3.4 Manage Event

Organizer actions:
- Edit permitted event details.
- Update inventory.
- View sales.
- View attendee list.
- Export permitted reports.
- View ticket scans.
- Send event announcements.
- Request cancellation.
- Request a change of date or venue.

Changes that materially affect ticket holders must trigger appropriate notification and refund workflows.

Price and inventory changes must not alter already-purchased tickets without a lawful, disclosed and supported process.

## 3.5 Attendee Management

Display only information necessary for event administration.

Possible fields:
- Booking reference.
- Ticket category.
- Ticket quantity.
- Attendee name, if collected.
- Check-in status.
- Check-in time.

Phone and email visibility must be restricted to authorized purposes. Do not expose full customer lists to unrelated organizers.

## 3.6 Organizer Settlement Dashboard

Display:
- Gross sales.
- Gateway transaction reference.
- Applicable gateway fees.
- Platform fees, if any.
- Taxes.
- Refunds.
- Adjustments.
- Net eligible settlement.
- Expected settlement status.
- Actual settlement status.
- Reconciliation reference.

Target settlement timing: 5–7 working days only if approved and supported by the payment provider's agreement and settlement configuration.

Do not promise a fixed settlement time before it is confirmed by the provider.

---

# PART 4 — QR SCANNER AND EVENT ENTRY

## 4.1 Scanner Interface

The scanner should be accessible only to authorized organizers and staff.

For each scan:
1. Authenticate the operator.
2. Read the QR token.
3. Verify the ticket and event against the backend.
4. Check payment/booking status.
5. Check cancellation/refund status.
6. Check whether the ticket was already used.
7. Record the check-in result.
8. Show a clear success or failure message.

Success screen:
- Valid Ticket.
- Ticket category.
- Event name.
- Check-in time.

Failure messages:
- Invalid ticket.
- Ticket already used.
- Booking not confirmed.
- Ticket cancelled/refunded.
- Wrong event.
- Verification unavailable.

Maintain an audit trail containing the operator, ticket reference, timestamp and result.

---

# PART 5 — ADMIN DASHBOARD

## 5.1 Admin Authentication

- Secure admin login.
- Multi-factor authentication where supported.
- Role-based permissions.
- Session timeout.
- Audit logs.
- Restricted access to sensitive data.

Do not use one shared admin account for all staff.

## 5.2 Admin Overview

Display:
- Total users.
- Total organizers.
- Events pending review.
- Published events.
- Ticket sales.
- Payment failures.
- Refund requests.
- Complaints.
- Suspicious activities.
- Settlement exceptions.

Financial dashboards must use reconciled transaction data.

## 5.3 User Management

Admin can:
- Search users.
- View account status.
- Suspend accounts for documented reasons.
- Review abuse reports.
- Process account deletion requests.
- Review support history with appropriate access controls.

Admin should not see passwords, full payment credentials or unnecessary private information.

## 5.4 Organizer Management

Admin can:
- Review onboarding.
- Verify submitted information.
- Request missing documents.
- Approve, reject or suspend organizers.
- Review reported events.
- Record reasons for decisions.
- Restrict access when fraud or safety concerns justify action.

## 5.5 Event Moderation

Admin can:
- Review event details.
- Review cover images and promotional content.
- Request corrections.
- Approve or reject events.
- Suspend listings.
- Handle complaints.
- Review permission documents where required.
- Record moderation decisions.

Create a review queue and maintain an audit log.

## 5.6 Payments and Refunds

Admin can:
- Search bookings.
- Inspect gateway references.
- View payment status.
- View settlement reconciliation.
- Initiate eligible refund requests through authorized gateway APIs.
- Track refund status.
- Review disputes and chargebacks.
- Investigate duplicate transactions.

Do not provide an admin button that directly changes a booking to PAID without verified payment evidence.

## 5.7 Platform Configuration

Authorized administrators can configure:
- Supported cities.
- Event categories.
- Featured listings.
- Booking limits.
- Notification templates.
- Cancellation rules within approved policy.
- Fees where applicable.
- Organizer permissions.
- Maintenance mode.

All financial configuration changes must be logged.

---

# PART 6 — PAYMENT ARCHITECTURE

## 6.1 Required Business Model

The intended model is an event-booking marketplace where organizers list events, customers buy tickets and eligible proceeds are settled to organizers.

JHOOMO must not assume that an ordinary payment gateway account automatically authorizes collecting funds for many unrelated organizers and distributing them later.

Before launch, confirm the appropriate payment-provider product, marketplace approval, linked-account onboarding, settlement model, KYC and documentation requirements.

Razorpay Route is one potential solution to evaluate, subject to approval and current provider terms.

Official reference: https://razorpay.com/route/

## 6.2 Required Backend Flow

1. Create booking intent.
2. Lock or reserve ticket inventory for a limited period.
3. Create the payment order through the approved gateway integration.
4. Record the gateway order reference.
5. Receive gateway response.
6. Verify payment server-side.
7. Process signed webhooks idempotently.
8. Confirm booking only when the transaction is verified and inventory conditions are satisfied.
9. Generate ticket.
10. Reconcile the transaction.
11. Process eligible settlement and refund events.

If payment succeeds but inventory or booking processing fails, create a reconciliation exception and apply the approved refund/recovery workflow.

## 6.3 Financial Records

Store:
- Internal transaction ID.
- Booking ID.
- Organizer ID.
- Gateway order ID.
- Gateway payment ID.
- Amount and currency.
- Gateway fee.
- Applicable taxes.
- Platform fee, if any.
- Refund amount.
- Settlement reference.
- Transaction timestamps.
- Current status.
- Reconciliation status.

Do not rely on screenshots as authoritative payment confirmation.

---

# PART 7 — LEGAL DOCUMENTS AND POLICY PAGES

The following policies must be accessible in the app, website or relevant checkout flow.

Final legal wording must be prepared or reviewed by a qualified Indian professional based on the actual business and payment model.

## 7.1 Terms and Conditions

Must cover:
- Platform operator's legal identity and contact details.
- Eligibility to use the platform.
- User account rules.
- Booking process.
- Ticket validity.
- Payment conditions.
- Organizer responsibilities.
- Event information accuracy.
- Event changes and cancellation.
- Refund procedures.
- Prohibited conduct.
- Intellectual property.
- Complaints and dispute handling.
- Liability limitations to the extent legally permitted.
- Suspension and termination.
- Changes to terms.
- Governing law and appropriate dispute-resolution provisions.

Do not insert unverified company names, registration numbers or addresses.

## 7.2 Privacy Policy

Must explain:
- Personal data collected.
- Purpose of collection.
- Lawful basis/consent mechanisms where applicable.
- Payment-provider data handling.
- Sharing with organizers.
- Service providers and hosting.
- Security measures.
- Data retention.
- Account deletion.
- User rights and grievance contact.
- Marketing communications.
- Location permissions.
- Cookies or analytics where used.
- Data-breach handling.
- Applicable children's data requirements.

Do not collect precise location, government ID or contacts unless genuinely necessary and properly disclosed.

The privacy implementation must follow applicable Indian data-protection requirements and the relevant commencement timeline.

Official reference: https://www.meity.gov.in/dpdp-rules-2025

## 7.3 Cancellation and Refund Policy

Must specify:
- Whether tickets are refundable.
- Applicable cancellation deadlines.
- Event cancellation process.
- Date/venue change process.
- Refund eligibility.
- Refund method.
- Expected processing timeline, stated accurately.
- Convenience fee and gateway-fee treatment.
- Partial cancellation rules.
- No-show policy.
- Dispute contact.

Never promise a refund timeline that the payment provider cannot support.

## 7.4 Organizer Agreement

The organizer agreement must define:
- Organizer identity and verification.
- Event listing accuracy.
- Venue permissions.
- Safety and compliance obligations.
- Ticket inventory and pricing.
- Applicable fees.
- Payment and settlement conditions.
- Tax responsibilities.
- Refund and cancellation obligations.
- Customer complaint handling.
- Prohibited events and activities.
- Intellectual-property rights.
- Use of event images and promotional content.
- Attendee data access restrictions.
- Fraud prevention.
- Indemnity and liability, subject to legal review.
- Suspension and termination.
- Recordkeeping and cooperation with investigations.

## 7.5 Event Listing and Content Policy

Prohibit or restrict:
- Fraudulent or misleading events.
- Unauthorized ticket resale.
- Illegal events.
- Counterfeit or infringing content.
- False venue or performer claims.
- Hate, harassment and abusive content.
- Dangerous or prohibited activities.
- Events lacking required permissions.

Provide a reporting mechanism and moderation process.

## 7.6 Payment and Settlement Policy

Explain:
- Payment processing.
- Organizer onboarding.
- Verification requirements.
- Settlement eligibility.
- Settlement schedule.
- Fees and deductions.
- Refund adjustments.
- Disputes and chargebacks.
- Failed settlement handling.
- Financial reconciliation.

## 7.7 Grievance Redressal

Display a real support email and contact details before launch.

Define:
- How users can submit complaints.
- Complaint reference number.
- Internal assignment.
- Escalation.
- Response tracking.
- Resolution records.

Applicable Indian e-commerce and consumer-law obligations must be assessed by legal counsel. Do not publish invented grievance officer details.

## 7.8 Data Deletion and Retention

Implement:
- Account deletion request.
- Identity verification before deletion where appropriate.
- Deletion or anonymization of data that no longer needs to be retained.
- Preservation of records where legally required.
- Access restrictions for retained records.
- Confirmation to the user where appropriate.

## 7.9 Additional Documents

Prepare where applicable:
- Cookie and tracking notice.
- Accessibility statement.
- Refund operations SOP.
- Organizer verification SOP.
- Security incident response plan.
- Law-enforcement request handling procedure.
- Staff confidentiality agreement.
- Intellectual-property and source-code agreement.
- Founder/contributor agreement.
- Data-processing/vendor agreements.
- Business continuity and backup plan.

---

# PART 8 — SECURITY AND PRIVACY REQUIREMENTS

Mandatory technical requirements:
- Enforce authorization on the backend.
- Use secure authentication and password/OTP handling.
- Restrict database access using least privilege.
- Validate all inputs server-side.
- Use HTTPS.
- Protect secrets using environment variables or a secrets manager.
- Never commit gateway secret keys to source control.
- Verify payment webhooks using the provider's official method.
- Apply rate limiting.
- Prevent duplicate booking and payment processing.
- Log important administrative actions.
- Encrypt sensitive data where appropriate.
- Back up critical data.
- Test recovery procedures.
- Provide a process for security incident response.
- Do not log OTPs, passwords, CVV or unnecessary sensitive data.

Do not treat frontend hiding as authorization. The backend must enforce all roles and permissions.

---

# PART 9 — DATA MODEL

Create a normalized and documented database schema. The following are logical entities; adapt field types to the selected database.

## 9.1 Core Tables/Collections

**users**
- id
- full_name
- mobile
- email
- profile_photo
- selected_city
- account_status
- created_at
- updated_at

**organizers**
- id
- owner_user_id
- organizer_name
- organizer_type
- verification_status
- contact_details
- approved_payment_account_reference
- created_at
- updated_at

**organizer_members**
- id
- organizer_id
- user_id
- role
- permissions
- status

**events**
- id
- organizer_id
- title
- slug
- description
- category_id
- cover_image
- gallery
- start_at
- end_at
- timezone
- venue_name
- address
- city
- location_visibility
- age_restriction
- event_status
- cancellation_policy_id
- created_at
- updated_at

**ticket_types**
- id
- event_id
- name
- description
- price
- quantity_total
- quantity_reserved
- quantity_sold
- sale_start
- sale_end
- ticket_status

**bookings**
- id
- public_booking_reference
- user_id
- event_id
- booking_status
- subtotal
- fees
- taxes
- total_amount
- currency
- created_at
- updated_at

**booking_items**
- id
- booking_id
- ticket_type_id
- quantity
- unit_price
- tax_amount
- fee_amount
- total_amount

**tickets**
- id
- booking_id
- event_id
- ticket_type_id
- unique_ticket_reference
- qr_token_hash_or_reference
- ticket_status
- checked_in_at
- checked_in_by

**payments**
- id
- booking_id
- provider
- provider_order_id
- provider_payment_id
- amount
- currency
- payment_status
- verified_at
- created_at

**refunds**
- id
- booking_id
- payment_id
- amount
- reason
- refund_status
- provider_refund_reference
- created_at
- completed_at

**settlements**
- id
- organizer_id
- event_id
- provider_settlement_reference
- gross_amount
- deductions
- net_amount
- settlement_status
- expected_at
- completed_at

**event_checkins**
- id
- ticket_id
- event_id
- operator_user_id
- result
- scanned_at
- device_reference

**notifications**
- id
- user_id
- type
- title
- body
- read_at
- created_at

**reports**
- id
- reporter_user_id
- event_id
- reason
- description
- report_status
- created_at
- resolved_at

**audit_logs**
- id
- actor_user_id
- action
- entity_type
- entity_id
- metadata
- created_at

Add indexes, foreign keys, unique constraints and access policies as appropriate.

Never store raw payment credentials or unnecessary identity documents in general-purpose tables.

---

# PART 10 — API REQUIREMENTS

Document the API contract before frontend integration.

Suggested endpoint groups:

**Authentication**
- POST /auth/send-otp
- POST /auth/verify-otp
- POST /auth/logout
- GET /me

**Events**
- GET /events
- GET /events/{eventId}
- GET /events/search
- GET /cities
- GET /categories

**Bookings**
- POST /bookings
- GET /bookings/{bookingId}
- GET /me/bookings
- POST /bookings/{bookingId}/cancel-request

**Payments**
- POST /payments/create-order
- POST /payments/verify
- POST /webhooks/razorpay

**Tickets**
- GET /tickets/{ticketId}
- POST /organizer/events/{eventId}/check-in

**Organizer**
- POST /organizer/apply
- POST /organizer/events
- PATCH /organizer/events/{eventId}
- GET /organizer/events/{eventId}/sales
- GET /organizer/events/{eventId}/attendees

**Admin**
- GET /admin/review-queue
- POST /admin/events/{eventId}/approve
- POST /admin/events/{eventId}/reject
- GET /admin/payments
- POST /admin/refunds/{refundId}/process

These are proposed routes, not an existing API. The developer must define request schemas, response schemas, authorization, error codes, idempotency and rate limits.

Do not expose privileged admin endpoints to ordinary users or organizers.

---

# PART 11 — TESTING AND ACCEPTANCE CRITERIA

Before release, verify:

1. A user can browse events without unnecessary friction.
2. Search and filters return correct events.
3. A booking cannot exceed available inventory.
4. Payment failure does not create a confirmed ticket.
5. A verified successful payment creates the correct booking.
6. Duplicate webhook events do not duplicate bookings or refunds.
7. Every confirmed ticket has a unique reference.
8. Duplicate QR scans are rejected.
9. Cancelled tickets cannot be checked in.
10. Organizers cannot access another organizer's private data.
11. Admin permissions are enforced on the backend.
12. Refund status matches the payment provider's records.
13. Settlement reports reconcile to provider records.
14. Private event addresses are not exposed publicly.
15. Users can submit account deletion requests.
16. Legal policies are accessible before the relevant action.
17. Errors, loading states and empty states work correctly.
18. The app works on supported Android devices and common screen sizes.
19. Critical flows are tested on slow or interrupted networks.
20. No real payment keys or personal data are included in public test builds.

Do not launch real ticket sales until payment, refund, security and support workflows have passed testing.

---

# PART 12 — DEPLOYMENT AND MAINTENANCE

The developer must deliver:
- Source code in a repository controlled by the business owner.
- Development and production environments.
- Database schema and migrations.
- Environment-variable documentation.
- Deployment instructions.
- API documentation.
- Admin access handover.
- Backup and restore instructions.
- Monitoring and error logging.
- Release checklist.
- Known-issues list.
- Technical handover documentation.

All production credentials and accounts must be controlled through documented business access. Do not leave the only copy of source code or production access with one developer.

Choose affordable managed infrastructure suitable for the expected traffic. Avoid overengineering before real usage validates the product.

---

# PART 13 — TEAM RESPONSIBILITIES

## Shyam Chaturvedi — Founder & Business Lead
- Product priorities.
- Brand and organizer relationships.
- Business operations.
- Budget and vendor decisions.
- Legal and accounting coordination.
- Final approval of launch readiness.

## Ankit Jatav — Technology & Development Lead
- Architecture.
- Frontend and backend implementation.
- Database and APIs.
- Payment integration.
- Security and QA.
- Deployment and documentation.

## Gaurav Yadav — Operations & Organizer Relations
- Organizer onboarding.
- Event data collection.
- Listing coordination.
- Event operations.
- Support coordination.
- Local partnerships.

Any future equity arrangement must be separately documented. The proposed 60/30/10 split does not constitute current issued shares in a proprietorship.

---

# PART 14 — DEVELOPMENT PHASES

**Phase 1: Foundation**
- Confirm brand availability.
- Finalize requirements.
- Choose technology stack.
- Define database and API contracts.
- Establish legal and payment requirements.

**Phase 2: Core MVP**
- Authentication.
- Event discovery.
- Event details.
- Organizer registration.
- Event creation.
- Admin review.

**Phase 3: Ticketing**
- Inventory management.
- Booking creation.
- Approved payment integration.
- Booking confirmation.
- QR ticket generation.
- Ticket scanner.

**Phase 4: Operations**
- Organizer sales dashboard.
- Settlement reconciliation.
- Refund workflow.
- Complaint management.
- Notifications.
- Security testing.

**Phase 5: Controlled Launch**
- Test with selected organizers.
- Verify payment and refund flows.
- Test entry scanning.
- Train support staff.
- Launch in Lucknow.
- Monitor errors and customer feedback.

Do not build every advanced feature before the basic booking and payment flow is reliable.

---

# PART 15 — DEVELOPER DELIVERY CHECKLIST

Before the project is considered complete, deliver:

- [x] Customer app.
- [x] Organizer panel.
- [x] Admin dashboard.
- [x] Authentication and role permissions.
- [x] Event discovery and search.
- [x] Event creation and moderation.
- [x] Ticket inventory and booking flow.
- [x] Approved payment gateway integration.
- [x] Server-side payment verification.
- [x] QR ticket generation and scanner.
- [x] Refund workflow.
- [x] Settlement reconciliation.
- [x] Notifications.
- [x] Terms, Privacy and Refund policy pages.
- [ ] Organizer Agreement acceptance flow.
- [x] Account deletion flow.
- [ ] Audit logs and security controls.
- [ ] Database schema and migrations.
- [ ] API documentation.
- [ ] Automated or repeatable test cases.
- [ ] Deployment documentation.
- [ ] Source code and access handover.
- [ ] Production launch checklist.

## FINAL PRODUCT REQUIREMENT

Build JHOOMO as a reliable, privacy-conscious event discovery and ticket booking platform for India, beginning with Lucknow.

Prioritize event discovery, verified bookings, reliable payment status, unique QR tickets, organizer usability, transparent refund rules and secure operations.

The system must be modular, maintainable and capable of scaling as the business grows.

**JHOOMO — Discover Events. Book Your Moment.**
1