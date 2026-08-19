# PCI DSS scoping statement — Pay Via Xpresspay

This document describes what data the **Pay Via Xpresspay** Koha plugin sends to Xpress-pay, what
Xpress-pay sends back, and what Koha retains.

It is a factual description of the plugin's behaviour at the commit named in section 8. It is not a
certification, and it does not determine any library's PCI DSS obligations — a library that accepts
card payments is a merchant and has obligations regardless of what Koha does. What this document
establishes is whether Koha itself sits inside the cardholder data environment.

---

## 1. Summary

| Assertion | Determination |
|---|---|
| Does this plugin **accept** cardholder data (PAN, CVV/CVC/CID, expiry date, track or chip data, PIN)? | **No** |
| Does this plugin **transmit** cardholder data to any system? | **No** |
| Does this plugin **store** cardholder data? | **No** |
| Does this plugin store any **card-derived** data (card brand, truncated PAN, authorisation code)? | **No** |
| Does the patron ever enter card details into a page served by Koha? | **No** |
| Does any Koha-served page frame, embed, script, or otherwise affect the processor's card-entry page? | **No** |

**Determination: Koha is outside the cardholder data environment.**

A patron who chooses to pay library fees online leaves the Koha catalogue entirely and is sent to a
payment page hosted and operated by Xpress-pay. Card details are typed into that page, travel to
Xpress-pay, and never reach Koha or ByWater Solutions' servers. When the payment completes,
Xpress-pay notifies Koha that a payment of a given amount succeeded, and Koha marks the selected
fees as paid.

### One term that looks like card data and is not

**Koha's `cardnumber` is a library card barcode, not a payment card number.** This plugin does
not transmit or store it in any case.

---

## 2. How a payment works

1. The patron selects fees in the OPAC. [`opac_online_payment_begin`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay.pm#L56) records a
   [one-time token](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay.pm#L76) and renders a form.
2. **Patron's browser** submits that form [by GET, directly to `https://pay.xpress-pay.com`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/opac_online_payment_begin.tt#L73),
   and the patron enters card details on Xpress-pay's page. Koha is not involved and receives
   nothing from that step.
3. **Xpress-pay** posts the result to `/api/v1/contrib/xpresspay/payment`
   ([`handle_payment`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/API.pm#L14)), which validates the token and
   [credits the payment](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/API.pm#L48).

There is no `opac_online_payment_end` in this plugin — the confirmation step is Xpress-pay's, and
crediting happens entirely on the notification.

## 3. Data sent to the payment processor

All fields travel in the **query string** of a browser GET ([the form](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/opac_online_payment_begin.tt#L73)):

| Field | Contents | Code |
|---|---|---|
| `a` | total amount | [`:85`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/opac_online_payment_begin.tt#L85) |
| `pk` | the Xpress-pay payment-type code — a merchant identifier, not a secret | [`:86`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/opac_online_payment_begin.tt#L86) |
| `n` | patron surname, firstname | [`:87`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/opac_online_payment_begin.tt#L87) |
| `addr` / `z` / `e` / `p` | patron address, zip, email, phone | [`:88-91`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/opac_online_payment_begin.tt#L88-L91) |
| `l1` / `l2` / `l3` | borrowernumber, accountline ids, the one-time token | [`:93-95`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/opac_online_payment_begin.tt#L93-L95) |

**Cardholder data in this table: none.** No PAN, CVV, expiry, track or PIN field is constructed
anywhere in this plugin. **This plugin has no shared secret or API key at all** — its only
configuration beyond the on/off switch is the [payment-type code](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay.pm#L118).

Because the method is GET, all of the patron data above lands in URLs — browser history, proxy
logs, and `Referer` headers. See §7.

## 4. Data received from the payment processor

**Authentication of this channel:** None — the endpoint accepts unauthenticated requests, with no
`x-koha-authorization` block and no signature. The sole control is the one-time token. See §7.

Sixteen parameters are declared in [`openapi.json`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/openapi.json); the plugin reads four:
[`l1`, `l2`, `l3` and `billAmount`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/API.pm#L14-L17). The declared-but-unread set
(`transactionId`, `fullName`, `address`, `zip`, `email`, `phone`, amounts, `key`,
`uid`, `timestamp`) contains **no card data** — no masked PAN, brand, expiry, or
authorisation code.

**The processor's transaction id is not persisted anywhere** — the accountline note is the static
literal [`Paid via Xpresspay`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/API.pm#L51), so reconciliation depends entirely on Xpress-pay's
records.

## 5. What Koha stores, and for how long

| Store | Contents | Retention |
|---|---|---|
| [`xpresspay_plugin_tokens`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay.pm#L144) | one-time token (`B<borrowernumber>T<epoch>`), created_on, borrowernumber | Deleted on successful payment. As of an unreleased change, a nightly job removes tokens older than seven days; at the reviewed commit, abandoned rows accumulated with no purge. [Dropped on uninstall](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay.pm#L165). |
| `accountlines` | amount from `billAmount`, note `Paid via Xpresspay` | Per the library's Koha retention settings |

**Logs:** two unconditional `warn`s fire on every payment —
[a dump of every accountline being paid](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/API.pm#L41) (borrowernumber, item, amounts, **fee
descriptions**, existing notes) and [the payment result](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/API.pm#L59) — into the web server error log,
kept for as long as the host's rotation policy says. No card data is available to be logged; the
patron-privacy exposure of fee descriptions is real. See §6.

**Credentials: none exist.** Nothing to encrypt; nothing in cleartext.

## 6. Patron personal data (outside PCI scope)

Name, address, zip, email, phone, borrowernumber and amounts go to Xpress-pay **in a URL query
string**; fee descriptions (which can name borrowed items) do not go to Xpress-pay but are written
to the log by the accountline dump above. Once transmitted, Xpress-pay's handling is governed by
their privacy policy and the library's agreement with them.

## 7. Known limitations

| Item | Bearing on this document | Status |
|---|---|---|
| The payment notification endpoint is unauthenticated, has no signature, and credits the caller-supplied `billAmount`; the plugin has no secret with which a signature could even be built. | Payment-record integrity — no card data is involved. | Open |
| All patron PII in §3 travels in a GET query string. | Patron privacy, not card data. | Open |
| Unconditional accountline dumps to the error log on every payment. | Patron privacy, not card data. | Open |
| The processor's transaction id is not stored, so a Koha credit cannot be traced to an Xpress-pay transaction from Koha's records. | Reconciliation. | Open |

## 8. What was reviewed

Reviewed at commit [`760c1e109ae600bd4f14819b6e4d806a769d91c0`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/commit/760c1e109ae600bd4f14819b6e4d806a769d91c0) on 2026-08-19:
[`PayViaXpresspay.pm`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay.pm), [`API.pm`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/API.pm), [`openapi.json`](https://github.com/bywatersolutions/koha-plugin-pay-via-xpresspay/blob/760c1e109ae600bd4f14819b6e4d806a769d91c0/Koha/Plugin/Com/ByWaterSolutions/PayViaXpresspay/openapi.json), and the OPAC templates.

| Date | Commit | Reviewer | Change |
|---|---|---|---|
| 2026-08-19 | `760c1e1` | Kyle M Hall | Initial review |
