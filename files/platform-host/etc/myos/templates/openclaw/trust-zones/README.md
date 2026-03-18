# Trust zones

The tenant template tree assumes three trust zones.

- Zone A: trusted control-plane and agent services
- Zone B: hostile-input browser and parsing workloads
- Zone C: storage and secrets kept separate from execution paths
