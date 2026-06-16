# HearTech Referral Dataset v2 + LoRA Training

Synthetic paediatric hearing referral letters for fine-tuning **Llama 3.2 3B** with MLX LoRA (`mask_prompt: true`).

## 1. Generate dataset (you — ~2–5 minutes)

```bash
cd /Users/noorhassan/HEARTECH_FYP/HEARTECH/backend/heartech_ai
python scripts/generate_referral_dataset_v2.py --train 12000 --valid 1500 --test 1500
python scripts/validate_dataset_v2.py --dir heartech_dataset_v2
```

Output: `heartech_dataset_v2/{train,valid,test}.jsonl` with `prompt` + `completion` fields.

## 2. Train LoRA (you — overnight, ~6–14 hours on M5 16GB)

Ensure your conda env has `mlx`, `mlx-lm` (same as backend).

```bash
cd /Users/noorhassan/HEARTECH_FYP/HEARTECH/backend/heartech_ai

python -m mlx_lm.lora \
  --model heartech_referral_model \
  --train \
  --data heartech_dataset_v2 \
  --adapter-path heartech_adapters_v2 \
  --batch-size 1 \
  --grad-checkpoint \
  --mask-prompt \
  --max-seq-length 1024 \
  --iters 8000 \
  --learning-rate 1e-5 \
  --lora-rank 16 \
  --lora-layers 8 \
  --steps-per-eval 200 \
  --save-every 500
```

Config reference: `heartech_adapters_v2/adapter_config.json`.

If you run out of memory, try `--max-seq-length 896` or `--lora-rank 8`.

## 3. Smoke test (you — 1 minute)

```bash
python -m mlx_lm.generate \
  --model heartech_referral_model \
  --adapter-path heartech_adapters_v2 \
  --prompt-file scripts/sample_prompt.txt \
  --max-tokens 900 \
  --temp 0.3
```

## 4. Run backend (you)

Restart uvicorn from `backend/`. The API uses `heartech_adapters_v2` automatically when present.

```bash
cd /Users/noorhassan/HEARTECH_FYP/HEARTECH/backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## 5. App test matrix (you — before viva)

| # | HCW instruction |
|---|-----------------|
| 1 | Suggest investigations |
| 2 | Make it urgent, ENT review within 2 weeks |
| 3 | Add speech therapy and parental guidance |
| 4 | LOW risk child profile |
| 5 | HIGH risk + family history + NICU |

Logs should show `[REFERRAL-AI] source=lora` or `source=base`.

## FYP report notes

- **Data:** 15k synthetic structured referrals; no patient PHI; no external LLM for training.
- **Method:** LoRA SFT with prompt masking on completion only.
- **Baseline:** Base Llama 3.2 3B without adapters for comparison during training analysis.
