___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "displayName": "FlowScan lead events",
  "categories": [
    "ANALYTICS",
    "CONVERSIONS",
    "ADVERTISING"
  ],
  "brand": {
    "id": "brand_dummy",
    "displayName": "FlowScan"
  },
  "description": "Sends one standard lead event (form submit, phone click, booking or chat start) to Google Analytics 4 and to the Meta pixel, with the SAME event ID on both, so a later server-side send (Meta Conversions API, GA4 Measurement Protocol) can be de-duplicated against it. No form values, emails or phone numbers are sent.",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "SELECT",
    "name": "eventName",
    "displayName": "Lead type",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "generate_lead",
        "displayValue": "Form submit (GA4 generate_lead, Meta Lead)"
      },
      {
        "value": "contact_phone",
        "displayValue": "Phone click (GA4 contact_phone, Meta Contact)"
      },
      {
        "value": "schedule_appointment",
        "displayValue": "Booking (GA4 schedule_appointment, Meta Schedule)"
      },
      {
        "value": "contact_chat",
        "displayValue": "Chat start (GA4 contact_chat, Meta Contact)"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "generate_lead",
    "help": "The event names are fixed on purpose: they are the standard names ad platforms and scanners recognise as a lead."
  },
  {
    "type": "CHECKBOX",
    "name": "sendGa4",
    "checkboxText": "Send to Google Analytics 4",
    "simpleValueType": true,
    "defaultValue": true
  },
  {
    "type": "TEXT",
    "name": "ga4MeasurementId",
    "displayName": "GA4 measurement ID",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^G-[A-Z0-9]{6,12}$"
        ]
      }
    ],
    "help": "For example G-XXXXXXXXXX. The GA4 Google tag with this ID must be on the page.",
    "enablingConditions": [
      {
        "paramName": "sendGa4",
        "paramValue": true,
        "type": "EQUALS"
      }
    ]
  },
  {
    "type": "CHECKBOX",
    "name": "sendMeta",
    "checkboxText": "Send to the Meta pixel",
    "simpleValueType": true,
    "defaultValue": true,
    "help": "Needs the Meta pixel base code already loaded on the page (it is not loaded here, so your consent rules for it keep applying). Without it only GA4 is sent."
  },
  {
    "type": "TEXT",
    "name": "eventId",
    "displayName": "Event ID (optional)",
    "simpleValueType": true,
    "help": "Leave empty to generate one per lead. Fill it with a data layer variable to reuse the ID your server already has for this lead (order or lead number), so a server-side send matches."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

const createArgumentsQueue = require('createArgumentsQueue');
const callInWindow = require('callInWindow');
const copyFromWindow = require('copyFromWindow');
const setInWindow = require('setInWindow');
const logToConsole = require('logToConsole');
const getTimestampMillis = require('getTimestampMillis');
const generateRandom = require('generateRandom');
const isConsentGranted = require('isConsentGranted');

// Meta has no custom names for these: its standard events are Lead, Contact and Schedule.
const META_NAMES = {
  generate_lead: 'Lead',
  contact_phone: 'Contact',
  schedule_appointment: 'Schedule',
  contact_chat: 'Contact'
};

// One ID per lead, shared by both destinations: that is what lets a later server-side send de-duplicate.
const eventId = data.eventId || 'fs_' + getTimestampMillis() + '_' + generateRandom(100000, 999999);
let sent = 0;

// Consent is checked per destination, so a visitor who granted analytics only still gets the GA4 event and
// never the Meta one (and the other way round).
if (data.sendGa4) {
  if (isConsentGranted('analytics_storage')) {
    // createArgumentsQueue defines window.gtag when the Google tag has not yet, and queues the call either way.
    const gtag = createArgumentsQueue('gtag', 'dataLayer');
    gtag('event', data.eventName, {event_id: eventId, send_to: data.ga4MeasurementId});
    sent++;
  } else {
    logToConsole('FlowScan lead events: analytics_storage is not granted, so GA4 was not sent.');
  }
}

if (data.sendMeta) {
  if (!isConsentGranted('ad_storage')) {
    logToConsole('FlowScan lead events: ad_storage is not granted, so Meta was not sent.');
  } else if (copyFromWindow('fbq')) {
    callInWindow('fbq', 'track', META_NAMES[data.eventName], {}, {eventID: eventId});
    sent++;
  } else {
    // Never load the pixel here: that would bypass the site's consent rules for it.
    logToConsole('FlowScan lead events: the Meta pixel is not on this page, so only GA4 was sent.');
  }
}

// Lets a server-side send read the same ID.
setInWindow('fs_last_lead_event_id', eventId, true);

if (sent) data.gtmOnSuccess();
else data.gtmOnFailure();


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "gtag"},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "dataLayer"},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "fbq"},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": true}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "key"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"},
                  {"type": 1, "string": "execute"}
                ],
                "mapValue": [
                  {"type": 1, "string": "fs_last_lead_event_id"},
                  {"type": 8, "boolean": false},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_consent",
        "versionId": "1"
      },
      "param": [
        {
          "key": "consentTypes",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "consentType"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"}
                ],
                "mapValue": [
                  {"type": 1, "string": "analytics_storage"},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {"type": 1, "string": "consentType"},
                  {"type": 1, "string": "read"},
                  {"type": 1, "string": "write"}
                ],
                "mapValue": [
                  {"type": 1, "string": "ad_storage"},
                  {"type": 8, "boolean": true},
                  {"type": 8, "boolean": false}
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Form submit sends GA4 generate_lead and Meta Lead with one event ID
  code: |-
    mock('isConsentGranted', true);
    const mockData = {
      eventName: 'generate_lead',
      sendGa4: true,
      ga4MeasurementId: 'G-TEST123456',
      sendMeta: true,
      eventId: 'lead-1'
    };

    runCode(mockData);

    assertApi('gtag').wasCalledWith('event', 'generate_lead', {event_id: 'lead-1', send_to: 'G-TEST123456'});
    assertApi('callInWindow').wasCalledWith('fbq', 'track', 'Lead', {}, {eventID: 'lead-1'});
    assertApi('gtmOnSuccess').wasCalled();
- name: Phone click maps to Meta Contact
  code: |-
    mock('isConsentGranted', true);
    const mockData = {
      eventName: 'contact_phone',
      sendGa4: true,
      ga4MeasurementId: 'G-TEST123456',
      sendMeta: true,
      eventId: 'lead-2'
    };

    runCode(mockData);

    assertApi('gtag').wasCalledWith('event', 'contact_phone', {event_id: 'lead-2', send_to: 'G-TEST123456'});
    assertApi('callInWindow').wasCalledWith('fbq', 'track', 'Contact', {}, {eventID: 'lead-2'});
- name: Booking maps to Meta Schedule
  code: |-
    mock('isConsentGranted', true);
    const mockData = {
      eventName: 'schedule_appointment',
      sendGa4: true,
      ga4MeasurementId: 'G-TEST123456',
      sendMeta: true,
      eventId: 'lead-3'
    };

    runCode(mockData);

    assertApi('callInWindow').wasCalledWith('fbq', 'track', 'Schedule', {}, {eventID: 'lead-3'});
- name: Chat start maps to Meta Contact
  code: |-
    mock('isConsentGranted', true);
    const mockData = {
      eventName: 'contact_chat',
      sendGa4: true,
      ga4MeasurementId: 'G-TEST123456',
      sendMeta: true,
      eventId: 'lead-4'
    };

    runCode(mockData);

    assertApi('gtag').wasCalledWith('event', 'contact_chat', {event_id: 'lead-4', send_to: 'G-TEST123456'});
    assertApi('callInWindow').wasCalledWith('fbq', 'track', 'Contact', {}, {eventID: 'lead-4'});
- name: Without the Meta pixel only GA4 is sent and the tag still succeeds
  code: |-
    mock('isConsentGranted', true);
    mock('copyFromWindow', function(key) {
      return undefined;
    });
    const mockData = {
      eventName: 'generate_lead',
      sendGa4: true,
      ga4MeasurementId: 'G-TEST123456',
      sendMeta: true,
      eventId: 'lead-5'
    };

    runCode(mockData);

    assertApi('gtag').wasCalledWith('event', 'generate_lead', {event_id: 'lead-5', send_to: 'G-TEST123456'});
    assertApi('callInWindow').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: With both destinations off the tag fails
  code: |-
    mock('isConsentGranted', true);
    const mockData = {
      eventName: 'generate_lead',
      sendGa4: false,
      sendMeta: false
    };

    runCode(mockData);

    assertApi('gtmOnFailure').wasCalled();
- name: The event ID is published for a server-side send
  code: |-
    mock('isConsentGranted', true);
    const mockData = {
      eventName: 'generate_lead',
      sendGa4: true,
      ga4MeasurementId: 'G-TEST123456',
      sendMeta: false,
      eventId: 'lead-6'
    };

    runCode(mockData);

    assertApi('setInWindow').wasCalledWith('fs_last_lead_event_id', 'lead-6', true);


- name: Without ad consent GA4 is still sent and Meta is not
  code: |-
    mock('isConsentGranted', function(type) {
      return type === 'analytics_storage';
    });
    const mockData = {
      eventName: 'generate_lead',
      sendGa4: true,
      ga4MeasurementId: 'G-TEST123456',
      sendMeta: true,
      eventId: 'lead-7'
    };

    runCode(mockData);

    assertApi('gtag').wasCalledWith('event', 'generate_lead', {event_id: 'lead-7', send_to: 'G-TEST123456'});
    assertApi('callInWindow').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();


___NOTES___

Created for FlowScan (flowscan.pro): one template import installs the lead events FlowScan recommends on any site with Google Tag Manager.
