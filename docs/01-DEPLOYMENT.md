# Deployment Guide

## Prerequisites

- Snowflake account with **Enterprise** edition or higher (required for SPCS + Cortex)
- `SYSADMIN` and `ACCOUNTADMIN` role access
- `SFE_GIT_API_INTEGRATION` already configured (shared infrastructure)
- Cortex AI functions enabled in your region
- **SPCS vision image pushed** (see below)

## SPCS Vision Image (one-time prerequisite)

The vision classification service requires a container image in your Snowflake image repository. This must be done **before** running `deploy_all.sql`.

**Install a container runtime** (if needed):

| Platform | Podman (free, Apache 2.0) | Docker (license required for commercial) |
|----------|--------------------------|------------------------------------------|
| macOS    | `brew install podman`    | Docker Desktop                           |
| Windows  | `winget install RedHat.Podman` | Docker Desktop                     |
| Linux    | `sudo apt install podman` / `dnf install podman` | `sudo apt install docker.io` |

**Run the push script:**

```bash
cd spcs/
./push-image.sh        # macOS / Linux / WSL
# .\push-image.ps1     # Windows PowerShell
```

The script will prompt for:
1. **Image repository URL** — run `SHOW IMAGE REPOSITORIES` in Snowsight after creating the repo, copy the `repository_url` column value
2. **PAT** — generate a Programmatic Access Token in Snowsight (user menu)

For repeated use, create `spcs/.env.local` (gitignored) with your values. See `spcs/.env.example` for the format.

## Quick Deploy (5 minutes)

1. Push the SPCS vision image (one-time, see above)
2. Open **Snowsight**
3. Create a **New SQL Worksheet**
4. Paste the entire contents of `deploy_all.sql`
5. Click **Run All**

The script handles everything: schema creation, sample data, classification runs, agent setup, and dashboard deployment.

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
