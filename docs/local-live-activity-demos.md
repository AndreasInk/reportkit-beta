# Local Live Activity Demos

Derived from the Craft doc `ReportKit Demo` and refined toward source-specific operator contexts:

- Mixpanel insights for product and growth changes.
- Supabase logs for backend failures.
- GCloud logs for infra incidents.
- App Store Connect analytics for storefront and acquisition shifts.
- Release readiness for shipping workflows.
- Passive "is anything on fire?" monitoring for founders and small teams.

The signed-in `Local Test Activity` menu now maps directly to these demo payloads.

## Example payloads

### Ops Calm

```json
{
  "event": "start",
  "activityId": "demo-opsCalm",
  "payload": {
    "generatedAt": 1774000000,
    "title": "Ops Calm",
    "summary": "No incidents are active. Revenue, payments, and API checks are all within normal range.",
    "status": "good",
    "action": "Keep the surface pinned for passive monitoring.",
    "deepLink": "reportkitsimple://demo/ops-calm",
    "visualStyle": "minimal"
  }
}
```

### Release Readiness

```json
{
  "event": "update",
  "activityId": "demo-releaseReadiness",
  "payload": {
    "generatedAt": 1774000100,
    "title": "Release Readiness",
    "summary": "The release candidate is green, but one blocking item remains: verify the latest App Store metadata before shipping.",
    "status": "warning",
    "action": "Check the submission checklist and metadata diff.",
    "deepLink": "reportkitsimple://demo/release-readiness",
    "visualStyle": "minimal"
  }
}
```

### Mixpanel Funnel

```json
{
  "event": "update",
  "activityId": "demo-mixpanelFunnel",
  "payload": {
    "generatedAt": 1774000200,
    "title": "Mixpanel Funnel",
    "summary": "Revenue is steady. Trial-to-paid dipped after yesterday's paywall experiment.",
    "status": "warning",
    "action": "Open the experiment and inspect the conversion cohort.",
    "deepLink": "reportkitsimple://demo/mixpanel-funnel",
    "visualStyle": "chart",
    "chartValues": [24, 31, 44, 58, 49, 67, 61],
    "chartTitle": "Trial -> Paid"
  }
}
```

### App Store Analytics

```json
{
  "event": "update",
  "activityId": "demo-appStoreAnalytics",
  "payload": {
    "generatedAt": 1774000300,
    "title": "App Store Analytics",
    "summary": "Product page conversion fell 18% after the new screenshots went live in the U.S. storefront.",
    "status": "warning",
    "action": "Compare screenshot sets and restore the better-performing variant.",
    "deepLink": "reportkitsimple://demo/app-store-analytics",
    "visualStyle": "chart",
    "chartValues": [5.4, 5.3, 5.2, 4.9, 4.6, 4.5, 4.4],
    "chartTitle": "Page Conversion (%)"
  }
}
```

### Supabase Errors

```json
{
  "event": "update",
  "activityId": "demo-supabaseErrors",
  "payload": {
    "generatedAt": 1774000400,
    "title": "Supabase Errors",
    "summary": "Edge function failures spiked to 127 in the last 10 minutes, mostly auth refresh and write timeouts.",
    "status": "critical",
    "action": "Open Supabase logs and roll back the latest function deploy.",
    "deepLink": "reportkitsimple://demo/supabase-errors",
    "visualStyle": "banner"
  }
}
```

### GCloud Incident

```json
{
  "event": "update",
  "activityId": "demo-gcloudIncident",
  "payload": {
    "generatedAt": 1774000500,
    "title": "GCloud Incident",
    "summary": "Cloud Run error rate crossed 4.2% and the newest deploy is returning upstream timeout bursts.",
    "status": "critical",
    "action": "Inspect GCloud logs and divert traffic from the failing revision.",
    "deepLink": "reportkitsimple://demo/gcloud-incident",
    "visualStyle": "banner"
  }
}
```
