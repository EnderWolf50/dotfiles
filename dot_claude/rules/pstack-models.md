# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit Task `model`). Alias entries in a panel list still count toward its fan-out.
# budget: large (xhigh); explainer, synthesizer, judge roles at high
feature, refactoring: opus xhigh
bug-fix: opus xhigh
perf-issue: opus xhigh
hillclimb: opus xhigh
judgment and prose: opus high
hardest tasks: opus xhigh
how explorer: inherit-parent
how explainer: opus high
why investigators: inherit-parent
why synthesizer: opus high
reflect tooling: inherit-parent
reflect judgment, divergent, synthesizer: opus high
arena runners: opus xhigh, fable xhigh
arena cross-judge pool: opus high, fable high
swarm workers: opus high
architect runners: opus xhigh, fable xhigh
interrogate reviewers: opus xhigh, fable xhigh
