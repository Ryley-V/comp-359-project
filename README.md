# Benchmarking and Complexity Analysis

To validate the efficiency of the spatial hash grid, we directly implemented a benchmarking system that toggles the simulation between the spatial hash mode, and a naive brute force algorithm mode. The naive approach checks every entity against each other and was used as a baseline for comparison against the Spatial hash method. We tested the simulation using 3 different entity amounts for each mode, and recorded the query time, candidate count, and collision count every 5 seconds. For each set of values tested, 5 outputs were recorded and averaged to get the results shown in the table below.


| Entities | Mode | Avg Query (ms) | Avg Candidates | Avg Collisions |
|----------|------|----------------|----------------|----------------|
| 500 | Spatial | 2.27 | 640 | 1 |
| 500 | Naive | 60.87 | 20 | 1 |
| 1000 | Spatial | 5.12 | 1579 | 3 |
| 1000 | Naive | 254.23 | 96 | 6 |
| 3000 | Spatial | 20.35 | 8311 | 53 |
| 3000 | Naive | 2219.12 | 821 | 49 |

The results confirmed the expected complexity difference. Naive query time showed consistent O(n^2) behaviour, with doubling entries causing a roughly 4x increase in query time. The Spatial Hash scaled nearly linearly across the same range. At 3000 entities, the spatial hash completed queries in around 20ms compared to the naive's 2200ms, approximately a 110x increase in speed.
