# Deployment Guide

## Prerequisites

- Snowflake account with **Enterprise** edition or higher (required for SPCS + Cortex)
- `SYSADMIN` and `ACCOUNTADMIN` role access
- `SFE_GIT_API_INTEGRATION` already configured (shared infrastructure)
- Cortex AI functions enabled in your region

## Quick Deploy (3 steps, ~10 minutes)

### Step 1 — Deploy core objects

1. Open **Snowsight**
2. Create a **New SQL Worksheet**
3. Paste the entire contents of `deploy_all.sql`
4. Click **Run All**

This creates the schema, sample data, three text-based classification approaches, the Streamlit dashboard, and the Intelligence agent. The **last result** shows your image repository URL — copy it for step 2.

### Step 2 — Push the SPCS vision image (one-time)

Requires [Podman](https://podman.io/) (free, Apache 2.0) or Docker:

| Platform | Install Podman |
|----------|---------------|
| macOS    | `brew install podman` |
| Windows  | `winget install RedHat.Podman` |
| Linux    | `sudo apt install podman` or `dnf install podman` |

```bash
cd spcs/
./push-image.sh        # macOS / Linux / WSL
# .\push-image.ps1     # Windows PowerShell
```

The script prompts for:
1. **Image repository URL** — copy from the last result of step 1
2. **Snowflake username**
3. **PAT** — generate a [Programmatic Access Token](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens) in Snowsight (user menu)

For repeated use, create `spcs/.env.local` (gitignored) with your values. See `spcs/.env.example` for the format.

### Step 3 — Deploy SPCS vision

1. Create a new SQL worksheet in Snowsight
2. Paste the entire contents of `deploy_spcs.sql`
3. Click **Run All**

This creates the vision service, classifies all image-only products, and shows the final accuracy comparison across all four approaches.

## What Gets Created

| Object | Type | Schema |
|--------|------|--------|
| `GLAZE_AND_CLASSIFY` | Schema | `SNOWFLAKE_EXAMPLE` |
| `SFE_GLAZE_AND_CLASSIFY_WH` | Warehouse (XS) | Account |
| `RAW_PRODUCTS` | Table | `GLAZE_AND_CLASSIFY` |
| `RAW_CATEGORY_TAXONOMY` | Table | `GLAZE_AND_CLASSIFY` |
| `RAW_KEYWORD_MAP` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_TRADITIONAL` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_CORTEX_SIMPLE` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_CORTEX_ROBUST` | Table | `GLAZE_AND_CLASSIFY` |
| `STG_CLASSIFIED_VISION` | Table | `GLAZE_AND_CLASSIFY` |
| `CLASSIFICATION_COMPARISON` | View | `GLAZE_AND_CLASSIFY` |
| `ACCURACY_SUMMARY` | View | `GLAZE_AND_CLASSIFY` |
| `SV_GLAZE_PRODUCTS` | Semantic View | `SEMANTIC_MODELS` |
| `GLAZE_CLASSIFIER_AGENT` | Agent | `GLAZE_AND_CLASSIFY` |
| `GLAZE_CLASSIFY_DASHBOARD` | Streamlit | `GLAZE_AND_CLASSIFY` |
| `GLAZE_VISION_SERVICE` | SPCS Service | `GLAZE_AND_CLASSIFY` |
| `SFE_GLAZE_VISION_POOL` | Compute Pool | Account |
| `CLASSIFY_IMAGE` | Function (SPCS) | `GLAZE_AND_CLASSIFY` |

## Expected Runtime

| Step | Duration |
|------|----------|
| Schema + tables + data | ~30 seconds |
| Traditional SQL classification | ~5 seconds |
| Cortex Simple classification | ~2 minutes |
| Cortex Robust classification | ~3 minutes |
| SPCS service startup | ~2 minutes |
| Vision classification | ~1 minute |
| Agent + Streamlit | ~30 seconds |
| **Total** | **~9 minutes** |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `DEMO EXPIRED` error | Update `SET DEMO_EXPIRES` date in `deploy_all.sql` |
| Git fetch fails | Verify `SFE_GIT_API_INTEGRATION` exists and has access to the repo |
| Cortex functions fail | Check that Cortex AI is enabled in your region |
| SPCS service won't start | Verify SPCS is available; check compute pool status with `SHOW COMPUTE POOLS` |
| `Image ... not found` | Run `spcs/push-image.sh` (or `.ps1`) to build and push the container image before deploying |
