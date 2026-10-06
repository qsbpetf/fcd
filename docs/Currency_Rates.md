# Currency rate import

A scheduled job loads the latest foreign-exchange rates, applies a markup, and stores them for Salesforce multi-currency and for Opportunity Products.

Quote and invoice import write the Atlassian USD amounts onto the Opportunity Product. They do not multiply those amounts by this rate. When the Opportunity Product is created, the **Exchange Rate Flow** copies the stored USD rate onto `Exchange_Rate__c`.

---

## Table of Contents

1. [Production schedule](#production-schedule)
2. [What the job writes](#what-the-job-writes)
3. [Markup](#markup)
4. [Where the rates are used](#where-the-rates-are-used)
5. [Failure email](#failure-email)

---

## Production schedule

| | |
| --- | --- |
| Scheduled job name | `Apex Morning Currency Rate Import` |
| Apex class | `CurrencyRateUpdateScheduler` |
| Queueable | `CurrencyRateUpdateQueueable` |
| Work | `CurrencyCtrl.updateCurrencyConversionRates` |
| Cron | `0 30 8 * * ?` |
| When | Every day at 08:30, org timezone `Europe/Helsinki` |
| State in production | WAITING |

The scheduler only enqueues the queueable. The callout runs in the queueable, because scheduled Apex cannot make callouts.

It runs 15 minutes before `Apex Morning Auto Invoice Import` (08:45), so Opportunity Products created by that import can see the same day's rate.

---

## What the job writes

`CurrencyCtrl.getRates` calls `callout:ExchangeRatesAPI/v1/latest` (named credential **Exchange Rates API**, endpoint `https://api.exchangeratesapi.io`). The access key is a query parameter on that call.

Only currencies that are active in Salesforce (`CurrencyType.IsActive`) are kept.

Then two sets of records are written for today:

| Target | Base | What is stored |
| --- | --- | --- |
| `DatedConversionRate` | Salesforce corporate currency | One dated conversion rate per active currency other than the corporate currency. `StartDate` is today. Inserted through the composite sObject API. |
| `Buying_Exchange_Rate__c` | USD | One row per active currency other than USD. `Exchange_Rate_from_USD_to_X__c` is how many units of that currency equal 1 USD, after markup, rounded to 4 decimal places. `CurrencyIsoCode` is the target currency. `Start_Date__c` is today. `Start_Date_Unique__c` is the date plus the currency code and is unique. |

The corporate currency is left out of `DatedConversionRate`. USD is left out of `Buying_Exchange_Rate__c`.

A second run on the same day fails the `Buying_Exchange_Rate__c` insert when `Start_Date_Unique__c` already exists for that currency. The dated-rate insert does not stop the method when the HTTP response is an error; it only logs the status. The buying-rate insert still runs after that.

---

## Markup

`CurrencyRateMarkup__mdt` (label **Currency Rate Markup**). One field: `MarkupPercent__c`.

The code applies `rate × (1 + MarkupPercent__c / 100)` to every currency that is not the base of that calculation. The API base currency, and USD when rebasing the buying rates, are not marked up.

| Record | Markup |
| --- | --- |
| `Default` | 3% |
| `GBP` | 1.5% |
| `CHF` | 3.8% |

Any active currency without its own row uses `Default`. Add a record whose developer name is the ISO code to override one currency.

The object description says the corporate currency is not marked up. That matches the dated-rate path when the API base currency is the corporate currency. A non-base currency always gets the markup, including when the buying-rate path rebases everything to USD.

---

## Where the rates are used

**Dated conversion rates** are Salesforce's own advanced-currency rates. Opportunities and reports in a non-corporate currency use them from the rate whose start date is in effect.

**Buying exchange rates** are read when an Opportunity Product is created. The before-save flow **Exchange Rate Flow** (`Exchange_Rate_Flow`) looks up `Buying_Exchange_Rate__c` for the Opportunity currency with `Start_Date__c` on or before today, newest first, and sets `OpportunityLineItem.Exchange_Rate__c` from `Exchange_Rate_from_USD_to_X__c`. If `Opportunity.FX_Rate_Override__c` is set, the flow uses that value instead.

`PortalQuoteConverter.getLatestCurrencyConversionFactor` still reads the older fields `Exchange_Rate_from_USD_to_EUR__c` and `Exchange_Rate_from_USD_to_GBP__c` on the newest `Buying_Exchange_Rate__c`. This job does not fill those two fields. It fills `Exchange_Rate_from_USD_to_X__c`. The line mappers also do not multiply imported Atlassian amounts by that factor.

---

## Failure email

If `CurrencyCtrl.updateCurrencyConversionRates` throws, `CurrencyRateUpdateQueueable` emails the running user. The scheduled job runs as the user who scheduled it, so that user receives **Error in Currency Rate Update Job**. The default scheduler constructor turns this email on.
