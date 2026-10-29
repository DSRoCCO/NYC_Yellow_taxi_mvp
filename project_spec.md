# NYC Yellow Taxi MVP contract

## Purpose and user

The portfolio MVP helps a reviewer understand historical Yellow Taxi demand, inspect validated retrospective forecasts, forecast 1–168 hours from the latest official record, and inspect a clearly labelled long-horizon seasonal scenario. It is not an operational dispatch, pricing, fleet, or incentive tool.

## Evidence contract

| MVP capability | Frozen evidence | Contract |
| --- | --- | --- |
| Historical diagnostic | `findings_register.csv` F01–F04 | 2019-01 to 2024-12, trip-level TLC records aggregated by approved rules. |
| Quality indicators | `data_quality_by_source_month.csv` | Count invalid timestamps separately; do not interpret exclusions as causal effects. |
| Geography | `zone_regime_profile.csv` | Compare regimes; no permanent zone ranking claim. |
| Predictive validation | `predictive_contract.csv`, `predictive_gate.csv` | `lag_calendar`, city plus ten approved zones, January 2022–December 2024 population, 1–24 hours. It excludes weather, flight, event, traffic, supply, price, tourism, and economic covariates. |
| Latest-official forecast | locally verified official TLC months | Rebuild after `download_latest_nyc_tlc_data()`. Forecast 1–168 hours from the true bundle cutoff; disclose publication lag. |
| Seasonal future scenario | 2022+ calendar pattern | Target within 24 months of cutoff; not an operational forecast and no recent observations or external covariates. |

## Acceptance and no-go

The bundle must record schema version, source-manifest SHA-256, cutoff, and generation time. The app rejects missing or incompatible bundles. Forecasts are historical demonstrations only, must show the 2024-12 cutoff, and must not produce intervention recommendations. Any source, schema, leakage, baseline, or coverage change requires pipeline regeneration and a new evaluation.
