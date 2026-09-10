#!/usr/bin/env python3
"""Deterministic base-cost guardrail for the approved Phase 3 topology."""

from __future__ import annotations

import argparse
import json
from decimal import Decimal, ROUND_HALF_UP


EKS_CONTROL_PLANE_HOURLY = Decimal("0.1000")
EC2_C7I_FLEX_LARGE_HOURLY = Decimal("0.08479")
RDS_DB_T4G_MICRO_HOURLY = Decimal("0.0160")
NLB_HOURLY = Decimal("0.0225")
PUBLIC_IPV4_HOURLY = Decimal("0.0050")
SECRETS_MANAGER_ENDPOINT_HOURLY = Decimal("0.0200")
PLANNING_RESERVE_HOURLY = Decimal("0.0100")

HOURLY_COSTS = {
    "eks_control_plane": EKS_CONTROL_PLANE_HOURLY,
    "ec2_c7i_flex_large_node": EC2_C7I_FLEX_LARGE_HOURLY,
    "rds_db_t4g_micro": RDS_DB_T4G_MICRO_HOURLY,
    "network_load_balancer": NLB_HOURLY,
    "public_ipv4": PUBLIC_IPV4_HOURLY,
    "secrets_manager_endpoint_two_azs": SECRETS_MANAGER_ENDPOINT_HOURLY,
    "planning_reserve": PLANNING_RESERVE_HOURLY,
}
WINDOWS = (4, 8, 24, 40, 730)
VARIABLE_COST_NOTE = (
    "Data processing, EBS/RDS storage, logs, NLCUs, secrets, backups, KMS API requests and taxes "
    "vary and require review before apply. Totals exclude the new alarm KMS key's "
    "$1/month base storage charge, prorated hourly (https://aws.amazon.com/kms/pricing/). "
    "Free plan usage consumes credits."
)


def money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def estimate() -> dict[str, object]:
    hourly_total = sum(HOURLY_COSTS.values(), start=Decimal("0"))
    totals = {f"{hours}h": str(money(hourly_total * hours)) for hours in WINDOWS}
    return {
        "currency": "USD",
        "hourly_components": {name: str(value) for name, value in HOURLY_COSTS.items()},
        "hourly_total": str(hourly_total),
        "totals": totals,
        "note": VARIABLE_COST_NOTE,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    args = parser.parse_args()
    result = estimate()

    if args.json:
        print(json.dumps(result, sort_keys=True))
        return

    print("AWS Phase 3 base cost estimate (USD)")
    for name, value in result["hourly_components"].items():
        print(f"  {name}: ${value}/h")
    print(f"  hourly_total: ${result['hourly_total']}/h")
    for window, value in result["totals"].items():
        print(f"  {window}: ${value}")
    print(f"Note: {result['note']}")


if __name__ == "__main__":
    main()
