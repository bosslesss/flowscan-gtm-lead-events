# FlowScan lead events: a Google Tag Manager tag template

One tag that sends a standard lead event to **Google Analytics 4** and to the **Meta pixel** with the **same
event ID**, so GA4 and Meta count the lead once each and a later server-side send (Meta Conversions API, GA4
Measurement Protocol) can be matched to it. No form value, email address or phone number is ever read or sent.

| Lead type | GA4 event | Meta event |
|---|---|---|
| Form submit | `generate_lead` | `Lead` |
| Phone click | `contact_phone` | `Contact` |
| Booking | `schedule_appointment` | `Schedule` |
| Chat start | `contact_chat` | `Contact` |

The names are fixed on purpose: they are the standard names that ad platforms and audit tools recognise as a lead.

## Install in 5 minutes (any site that already runs Tag Manager)

1. **Import the ready-made container pieces.** Tag Manager > Admin > *Import Container* > choose
   `container_import.json` > pick your workspace > **Merge** > *Rename conflicting* (never *Overwrite*).
   It adds the template, 4 triggers, the bridge tag `FS lead - listeners`, 4 lead tags (`FS lead - form submit`,
   `phone click`, `booking`, `chat start`), one constant variable and the built-in variable *Click URL*.
   Nothing is published by importing.
2. **Set your GA4 ID.** Open the variable `FS lead - GA4 measurement ID` and replace `G-XXXXXXXXXX` with your own
   measurement ID (Google Analytics > Admin > Data streams). The GA4 Google tag must already be on the page.
3. **Meta pixel.** The pixel base code must already be on the page (the template never loads it, so your consent
   rules for the pixel keep applying). With no pixel on the page only GA4 is sent, and a line is written to the
   console of Tag Manager's preview.
4. **Preview.** Click *Preview*, open your site, click a `tel:` link, then submit a form, and check that each
   `FS lead - ...` tag fired once. In GA4 *Admin > DebugView* and Meta *Events Manager > Test events* the lead
   shows once each, with the same event ID (GA4 shows it as the parameter `event_id`, Meta as `event_id`).
5. **Publish** when you are happy.

Without the import file you can add the template from the Community Template Gallery and create your own tag
and trigger per lead type.

## What the bridge covers (and what it does not)

`FS lead - listeners` (a small ES5 Custom HTML tag, fired once on All Pages) pushes one data layer event for tools
that announce a lead only in the browser, never a field value:

* plain HTML `<form>` submits (search forms are skipped) -> `fs_form_submit`
* Contact Form 7 (`wpcf7mailsent`, after the mail was sent), HubSpot forms (`onFormSubmitted`) -> `fs_form_submit`
* Calendly (`calendly.event_scheduled`) -> `fs_booking`
* Tidio (first visitor message) -> `fs_chat_start`
* `tel:` links need no bridge: the trigger `FS lead - phone click (tel link)` watches link clicks.

Not covered: forms that submit by a script without a submit event, embedded forms inside an `iframe` from another
domain that do not post a message, and any chat tool other than Tidio. For those, push the event yourself:
`dataLayer.push({event: 'fs_form_submit'})` (or `fs_booking`, `fs_chat_start`) from the tool's success callback.

## Consent

Each destination is checked separately in the template: GA4 is sent only if `analytics_storage` is granted, Meta
only if `ad_storage` is granted. A visitor who granted analytics only still gives you the GA4 event. The tags carry
no tag-level consent requirement for that reason (a requirement for both would block GA4 for that visitor). With no
consent for either destination nothing is sent and the tag reports failure.

## Avoid counting a lead twice

GTM re-dispatches `gtag('event', ...)` as a custom event. If your container already has a trigger or tag on the
same event name (for example a regex trigger on `generate_lead` or a Meta `Lead` tag), it will see this tag's event
too. Exclude the template's sends from your existing tags, or leave the lead type to one of the two setups.

## Checks

The sandbox code is run under an emulator of the Tag Manager APIs by the Node script in this folder, together with
the scenarios stored in `template.tpl`. Inside the FlowScan repo the Python checks also verify the import file and
that FlowScan's scanner reads the events as lead events configured in Tag Manager.

## Licence

Apache 2.0, see `LICENSE`.
