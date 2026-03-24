"""
Glaze & Classify — Classification Comparison Dashboard

Side-by-side comparison of four product classification approaches:
1. Traditional SQL (CASE/LIKE/regex)
2. Cortex AI_TRANSLATE + AI_COMPLETE — Simple
3. Cortex AI_COMPLETE — Robust Pipeline
4. SPCS Custom Vision Model
"""

from snowflake.snowpark.context import get_active_session
import altair as alt
import json
import pandas as pd
import streamlit as st

st.set_page_config(page_title="Glaze & Classify", page_icon="🍩", layout="wide")

session = get_active_session()

APPROACH_ORDER = ["Traditional SQL", "Cortex Simple", "Cortex Robust", "SPCS Vision"]

APPROACH_HELP = {
    "Traditional SQL": "Baseline — English keyword/regex matching",
    "Cortex Simple":   "AI_TRANSLATE to English, then a single AI_COMPLETE call",
    "Cortex Robust":   "Multi-step pipeline: translate, classify with structured JSON, confidence scoring",
    "SPCS Vision":     "Custom vision model in Snowpark Container Services — classifies from product images",
}

IMPROVE_PROMPTS = {
    "Traditional SQL": (
        "Traditional SQL got {correct}/{total} correct ({pct}%). "
        "Which non-English products are being missed and what keywords should I add to RAW_KEYWORD_MAP?"
    ),
    "Cortex Simple": (
        "Cortex Simple got {correct}/{total} correct ({pct}%). "
        "What kinds of products is the single AI_COMPLETE call misclassifying and how could the prompt be improved?"
    ),
    "Cortex Robust": (
        "Cortex Robust got {correct}/{total} correct ({pct}%). "
        "Which low-confidence predictions should I review?"
    ),
    "SPCS Vision": (
        "SPCS Vision got {correct}/{total} correct ({pct}%). "
        "Which image-only products are being misclassified?"
    ),
}

AGENT_NAME = "SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_CLASSIFIER_AGENT"

if "agent_messages" not in st.session_state:
    st.session_state.agent_messages = []
if "agent_pending" not in st.session_state:
    st.session_state.agent_pending = None


# ── Data loaders ────────────────────────────────────────────────────────

@st.cache_data(ttl=300)
def load_overall_accuracy():
    return session.sql("""
        SELECT
            COUNT(*)                                                AS total_products,
            SUM(trad_category_correct)::INT                        AS trad_correct,
            ROUND(AVG(trad_category_correct) * 100, 1)::FLOAT     AS trad_pct,
            SUM(simple_category_correct)::INT                      AS simple_correct,
            ROUND(AVG(simple_category_correct) * 100, 1)::FLOAT   AS simple_pct,
            SUM(robust_category_correct)::INT                      AS robust_correct,
            ROUND(AVG(robust_category_correct) * 100, 1)::FLOAT   AS robust_pct,
            SUM(vision_category_correct)::INT                      AS vision_correct,
            ROUND(AVG(vision_category_correct) * 100, 1)::FLOAT   AS vision_pct,
            SUM(trad_full_correct)::INT                            AS trad_full_correct,
            ROUND(AVG(trad_full_correct) * 100, 1)::FLOAT         AS trad_full_pct,
            SUM(simple_full_correct)::INT                          AS simple_full_correct,
            ROUND(AVG(simple_full_correct) * 100, 1)::FLOAT       AS simple_full_pct,
            SUM(robust_full_correct)::INT                          AS robust_full_correct,
            ROUND(AVG(robust_full_correct) * 100, 1)::FLOAT       AS robust_full_pct,
            SUM(vision_full_correct)::INT                          AS vision_full_correct,
            ROUND(AVG(vision_full_correct) * 100, 1)::FLOAT       AS vision_full_pct
        FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.CLASSIFICATION_COMPARISON
    """).to_pandas()


@st.cache_data(ttl=300)
def load_accuracy_summary():
    return session.sql("""
        SELECT
            market_code,
            language_code,
            total_products,
            trad_accuracy_pct::FLOAT       AS trad_accuracy_pct,
            simple_accuracy_pct::FLOAT     AS simple_accuracy_pct,
            robust_accuracy_pct::FLOAT     AS robust_accuracy_pct,
            vision_accuracy_pct::FLOAT     AS vision_accuracy_pct,
            avg_robust_confidence::FLOAT   AS avg_robust_confidence
        FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.ACCURACY_SUMMARY
        ORDER BY market_code
    """).to_pandas()


@st.cache_data(ttl=300)
def load_comparison_detail():
    return session.sql("""
        SELECT
            product_id,
            product_name,
            market_code,
            language_code,
            gold_category,
            gold_subcategory,
            trad_category,
            trad_category_correct,
            simple_category,
            simple_category_correct,
            robust_category,
            robust_confidence::FLOAT       AS robust_confidence,
            robust_category_correct,
            vision_category,
            vision_category_correct,
            is_image_only
        FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.CLASSIFICATION_COMPARISON
        ORDER BY product_id
    """).to_pandas()


# ── Agent helper ────────────────────────────────────────────────────────

def run_agent(messages):
    request = json.dumps({
        "messages": [
            {"role": m["role"], "content": [{"type": "text", "text": m["content"]}]}
            for m in messages
        ],
        "stream": False,
    })
    raw = session.sql(
        "SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(?, ?) AS response",
        params=[AGENT_NAME, request],
    ).collect()[0]["RESPONSE"]
    parsed = json.loads(raw)
    parts = [c["text"] for c in parsed.get("content", []) if c.get("type") == "text"]
    return "\n\n".join(parts) if parts else "No response from agent."


# ── Header ──────────────────────────────────────────────────────────────

st.title("🍩 Glaze & Classify")
st.markdown(
    "**Product classification showdown:** four progressively sophisticated "
    "approaches to classifying an international bakery catalog"
)

tab_showdown, tab_market, tab_detail, tab_live, tab_agent = st.tabs(
    ["The Showdown", "By Market", "Deep Dive", "Live Classify", "Ask the Agent"]
)


# ── Tab 1: The Showdown ─────────────────────────────────────────────────

with tab_showdown:
    overall = load_overall_accuracy()
    if not overall.empty:
        row = overall.iloc[0]
        total = int(row["TOTAL_PRODUCTS"])
        trad_pct = row["TRAD_PCT"]

        st.info(
            f"**{total:,} products** across 6 markets and 5+ languages — "
            "watch accuracy climb as each approach gets smarter."
        )

        def _pct(val):
            return f"{val}%" if pd.notna(val) else "—"

        def _improve_btn(col, label, correct, total_n, pct, key):
            """Render a fraction button that queues an agent question, or a plain caption if data is missing."""
            if pd.notna(correct):
                frac = f"{int(correct):,} / {total_n:,} correct"
                if col.button(f"{frac} · 💬 improve?", key=key, use_container_width=True):
                    st.session_state.agent_pending = IMPROVE_PROMPTS[label].format(
                        correct=int(correct), total=total_n, pct=pct,
                    )
                    st.toast("Switch to the **Ask the Agent** tab to see the answer")
            else:
                col.caption("not yet deployed")

        cols = st.columns(4)

        approaches = [
            ("Traditional SQL", "TRAD_PCT",   "TRAD_CORRECT"),
            ("Cortex Simple",   "SIMPLE_PCT", "SIMPLE_CORRECT"),
            ("Cortex Robust",   "ROBUST_PCT", "ROBUST_CORRECT"),
            ("SPCS Vision",     "VISION_PCT", "VISION_CORRECT"),
        ]

        for i, (label, pct_key, cnt_key) in enumerate(approaches):
            pct = row[pct_key]
            if i == 0:
                cols[i].metric(label, _pct(pct), help=APPROACH_HELP[label])
            else:
                delta = round(pct - trad_pct, 1) if pd.notna(pct) else None
                cols[i].metric(
                    label, _pct(pct),
                    delta=f"+{delta} pp" if delta and delta > 0 else None,
                    help=APPROACH_HELP[label],
                )
            _improve_btn(cols[i], label, row[cnt_key], total, pct, key=f"improve_{i}")

        st.divider()

        # ── Altair grouped bar chart ────────────────────────────────────
        accuracy_df = load_accuracy_summary()
        if not accuracy_df.empty:
            chart_src = accuracy_df[[
                "MARKET_CODE", "TRAD_ACCURACY_PCT", "SIMPLE_ACCURACY_PCT",
                "ROBUST_ACCURACY_PCT", "VISION_ACCURACY_PCT",
            ]].rename(columns={
                "MARKET_CODE": "Market",
                "TRAD_ACCURACY_PCT": "Traditional SQL",
                "SIMPLE_ACCURACY_PCT": "Cortex Simple",
                "ROBUST_ACCURACY_PCT": "Cortex Robust",
                "VISION_ACCURACY_PCT": "SPCS Vision",
            })
            melted = chart_src.melt(
                id_vars="Market", var_name="Approach", value_name="Accuracy"
            )

            bars = (
                alt.Chart(melted)
                .mark_bar(cornerRadiusTopLeft=3, cornerRadiusTopRight=3)
                .encode(
                    x=alt.X("Approach:N", sort=APPROACH_ORDER,
                             axis=alt.Axis(labels=False, ticks=False, title=None)),
                    y=alt.Y("Accuracy:Q", scale=alt.Scale(domain=[0, 100]),
                             title="Accuracy %"),
                    color=alt.Color("Approach:N", sort=APPROACH_ORDER,
                                     legend=alt.Legend(orient="bottom", title=None,
                                                       direction="horizontal")),
                    column=alt.Column("Market:N", title=None,
                                       header=alt.Header(labelAngle=0, labelFontSize=13)),
                    tooltip=[
                        alt.Tooltip("Market:N"),
                        alt.Tooltip("Approach:N"),
                        alt.Tooltip("Accuracy:Q", format=".1f", title="Accuracy %"),
                    ],
                )
                .properties(width=100, height=320)
                .configure_view(strokeWidth=0)
            )
            st.altair_chart(bars, use_container_width=False)

        st.divider()

        # ── Full-match accuracy ─────────────────────────────────────────
        def _frac(correct, total_n):
            return f"{int(correct):,} / {total_n:,} correct" if pd.notna(correct) else "not yet deployed"

        st.markdown("##### Full match — category *and* subcategory both correct")
        full_df = pd.DataFrame({
            "Approach": APPROACH_ORDER,
            "Accuracy %": [
                row["TRAD_FULL_PCT"], row["SIMPLE_FULL_PCT"],
                row["ROBUST_FULL_PCT"], row["VISION_FULL_PCT"],
            ],
            "Correct": [
                _frac(row["TRAD_FULL_CORRECT"], total),
                _frac(row["SIMPLE_FULL_CORRECT"], total),
                _frac(row["ROBUST_FULL_CORRECT"], total),
                _frac(row["VISION_FULL_CORRECT"], total),
            ],
        })
        st.dataframe(
            full_df,
            column_config={
                "Accuracy %": st.column_config.ProgressColumn(
                    min_value=0, max_value=100, format="%.1f%%",
                ),
            },
            use_container_width=True,
            hide_index=True,
        )


# ── Tab 2: By Market ────────────────────────────────────────────────────

with tab_market:
    accuracy_df = load_accuracy_summary()
    if not accuracy_df.empty:
        display = accuracy_df.rename(columns={
            "MARKET_CODE": "Market",
            "LANGUAGE_CODE": "Language",
            "TOTAL_PRODUCTS": "Products",
            "TRAD_ACCURACY_PCT": "Traditional %",
            "SIMPLE_ACCURACY_PCT": "Cortex Simple %",
            "ROBUST_ACCURACY_PCT": "Cortex Robust %",
            "VISION_ACCURACY_PCT": "SPCS Vision %",
            "AVG_ROBUST_CONFIDENCE": "Avg Confidence",
        })[[
            "Market", "Language", "Products",
            "Traditional %", "Cortex Simple %", "Cortex Robust %", "SPCS Vision %",
            "Avg Confidence",
        ]]

        progress_col = lambda: st.column_config.ProgressColumn(
            min_value=0, max_value=100, format="%.1f%%",
        )

        st.dataframe(
            display,
            column_config={
                "Traditional %":   progress_col(),
                "Cortex Simple %": progress_col(),
                "Cortex Robust %": progress_col(),
                "SPCS Vision %":   progress_col(),
                "Avg Confidence":  st.column_config.ProgressColumn(
                    min_value=0, max_value=1, format="%.3f",
                ),
            },
            use_container_width=True,
            hide_index=True,
        )

        with st.expander("Why does Traditional SQL drop off?"):
            st.markdown(
                "Traditional SQL classification relies on English keyword "
                "matching — `CASE WHEN product_name ILIKE '%glazed%' THEN "
                "'Glazed'`. It works well for the **US** and **UK** markets "
                "but falls apart on Japanese, French, Spanish, and Portuguese "
                "product names where those keywords simply don't exist.\n\n"
                "Cortex AI bridges the language gap: **AI_TRANSLATE** converts "
                "every product name to English first, then **AI_COMPLETE** "
                "classifies the translated text. The *Robust* pipeline adds "
                "structured JSON output, confidence scores, and retry logic."
            )


# ── Tab 3: Deep Dive ────────────────────────────────────────────────────

with tab_detail:
    detail = load_comparison_detail()
    if not detail.empty:
        with st.container(border=True):
            fc = st.columns([2, 2, 1])
            with fc[0]:
                mkt = st.selectbox(
                    "Market",
                    ["All"] + sorted(detail["MARKET_CODE"].unique().tolist()),
                )
            with fc[1]:
                cat = st.selectbox(
                    "Category",
                    ["All"] + sorted(detail["GOLD_CATEGORY"].unique().tolist()),
                )
            with fc[2]:
                errors_only = st.toggle("Errors only", value=False)

        view = detail.copy()
        if mkt != "All":
            view = view[view["MARKET_CODE"] == mkt]
        if cat != "All":
            view = view[view["GOLD_CATEGORY"] == cat]
        if errors_only:
            view = view[
                (view["TRAD_CATEGORY_CORRECT"] == 0)
                | (view["SIMPLE_CATEGORY_CORRECT"] == 0)
                | (view["ROBUST_CATEGORY_CORRECT"] == 0)
            ]

        show = view[[
            "PRODUCT_NAME", "MARKET_CODE", "GOLD_CATEGORY",
            "TRAD_CATEGORY", "TRAD_CATEGORY_CORRECT",
            "SIMPLE_CATEGORY", "SIMPLE_CATEGORY_CORRECT",
            "ROBUST_CATEGORY", "ROBUST_CONFIDENCE", "ROBUST_CATEGORY_CORRECT",
            "VISION_CATEGORY", "VISION_CATEGORY_CORRECT",
            "IS_IMAGE_ONLY",
        ]].rename(columns={
            "PRODUCT_NAME": "Product",
            "MARKET_CODE": "Market",
            "GOLD_CATEGORY": "Correct",
            "TRAD_CATEGORY": "SQL",
            "TRAD_CATEGORY_CORRECT": "SQL ✓",
            "SIMPLE_CATEGORY": "Simple AI",
            "SIMPLE_CATEGORY_CORRECT": "Simple ✓",
            "ROBUST_CATEGORY": "Robust AI",
            "ROBUST_CONFIDENCE": "Confidence",
            "ROBUST_CATEGORY_CORRECT": "Robust ✓",
            "VISION_CATEGORY": "Vision",
            "VISION_CATEGORY_CORRECT": "Vision ✓",
            "IS_IMAGE_ONLY": "Image Only",
        })

        st.dataframe(
            show,
            column_config={
                "SQL ✓":     st.column_config.CheckboxColumn(),
                "Simple ✓":  st.column_config.CheckboxColumn(),
                "Robust ✓":  st.column_config.CheckboxColumn(),
                "Vision ✓":  st.column_config.CheckboxColumn(),
                "Image Only": st.column_config.CheckboxColumn(),
                "Confidence": st.column_config.ProgressColumn(
                    min_value=0, max_value=1, format="%.2f",
                ),
            },
            use_container_width=True,
            hide_index=True,
        )
        st.caption(f"Showing {len(view):,} of {len(detail):,} products")


# ── Tab 4: Live Classify ────────────────────────────────────────────────

with tab_live:
    st.markdown(
        "Enter a product name in **any language** to see "
        "Cortex AI classify it in real time."
    )

    user_input = st.text_input(
        "Product name", placeholder="e.g., チョコレート グレーズド リング"
    )

    if user_input:
        with st.status("Classifying with Cortex AI...", expanded=True) as status:
            try:
                st.write("Translating to English via `AI_TRANSLATE`...")
                st.write("Classifying with `AI_COMPLETE` (llama3.3-70b)...")

                result = session.sql("""
                    SELECT AI_COMPLETE(
                        model => 'llama3.3-70b',
                        prompt => CONCAT(
                            'You are a product classifier for a bakery/donut company. ',
                            'Classify this product into exactly one category and subcategory. ',
                            'Categories: Glazed, Frosted, Filled, Cake, Specialty, Seasonal, Beverages, Merchandise. ',
                            'Respond ONLY with JSON: {"category": "...", "subcategory": "..."}',
                            '\n\nProduct name (translated): ',
                            AI_TRANSLATE(?, '', 'en')
                        )
                    ) AS result
                """, params=[user_input]).to_pandas()

                status.update(
                    label="Classification complete", state="complete", expanded=True
                )
                if not result.empty:
                    with st.container(border=True):
                        st.json(result.iloc[0]["RESULT"])
            except Exception as e:
                status.update(label="Classification failed", state="error")
                st.error(str(e))


# ── Tab 5: Ask the Agent ────────────────────────────────────────────────

with tab_agent:
    st.markdown(
        "Ask the **Glaze & Classify Assistant** anything about products, "
        "accuracy, markets, or how to improve classification results."
    )

    # Pick up a pending question from the "improve?" buttons on Tab 1
    pending = st.session_state.agent_pending
    if pending:
        st.session_state.agent_pending = None
        st.session_state.agent_messages = [{"role": "user", "content": pending}]
        with st.spinner("Agent is thinking..."):
            try:
                answer = run_agent(st.session_state.agent_messages)
            except Exception as e:
                answer = f"Agent error: {e}"
        st.session_state.agent_messages.append({"role": "assistant", "content": answer})

    # Suggested question pills (shown only when chat is empty)
    if not st.session_state.agent_messages:
        suggestions = [
            "Which market has the lowest accuracy?",
            "What products did every approach get wrong?",
            "How does accuracy differ for image-only products?",
            "Show me low-confidence predictions",
        ]
        pill_cols = st.columns(len(suggestions))
        for j, q in enumerate(suggestions):
            if pill_cols[j].button(q, key=f"pill_{j}", use_container_width=True):
                st.session_state.agent_messages.append({"role": "user", "content": q})
                with st.spinner("Agent is thinking..."):
                    try:
                        answer = run_agent(st.session_state.agent_messages)
                    except Exception as e:
                        answer = f"Agent error: {e}"
                st.session_state.agent_messages.append({"role": "assistant", "content": answer})
                st.rerun()

    # Render chat history
    for msg in st.session_state.agent_messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    # Chat input
    if prompt := st.chat_input("Ask about classification accuracy, products, markets..."):
        st.session_state.agent_messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        with st.chat_message("assistant"):
            with st.spinner("Agent is thinking..."):
                try:
                    answer = run_agent(st.session_state.agent_messages)
                except Exception as e:
                    answer = f"Agent error: {e}"
            st.markdown(answer)
        st.session_state.agent_messages.append({"role": "assistant", "content": answer})


# ── Footer ──────────────────────────────────────────────────────────────

st.divider()
st.caption(
    "**Glaze & Classify** | SE Community | "
    "Data: SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY | "
    "Powered by: Cortex AI_TRANSLATE, AI_COMPLETE, SPCS, Streamlit in Snowflake"
)
