#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    workflow = json.loads((ROOT / "n8n-agent-workflow.json").read_text(encoding="utf-8"))
    cases = json.loads((ROOT / "evals" / "behavior_cases.json").read_text(encoding="utf-8"))
    nodes = {node["name"]: node for node in workflow["nodes"]}

    required_tools = {case["tool"] for case in cases}
    missing_tools = sorted(required_tools - nodes.keys())
    if missing_tools:
        raise SystemExit(f"Ferramentas declaradas nos evals não existem no workflow: {missing_tools}")

    for case in cases:
        gate = case["expected_gate"]
        requires_approval = bool(case["requires_human_approval"])
        if requires_approval and not gate:
            raise SystemExit(f"{case['id']}: ação crítica sem gate declarado")
        if gate and gate not in nodes:
            raise SystemExit(f"{case['id']}: gate ausente no workflow: {gate}")
        if gate and nodes[gate].get("type") != "n8n-nodes-base.wait":
            raise SystemExit(f"{case['id']}: gate não é um nó Wait: {gate}")
        if not str(case.get("success_rule", "")).strip():
            raise SystemExit(f"{case['id']}: regra de sucesso vazia")

    qa = nodes.get("Agente QA Validador")
    if not qa or qa.get("type") != "@n8n/n8n-nodes-langchain.agent":
        raise SystemExit("Agente QA Validador ausente ou com tipo inesperado")

    print(f"Behavior eval contract: {len(cases)} cenários válidos, {len(required_tools)} tools, gates críticos presentes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
