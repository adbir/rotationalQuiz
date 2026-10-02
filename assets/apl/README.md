# Bundled APLs

These files are copied verbatim from the SimulationCraft repository so the
app works offline. The app can download the latest version at runtime from
the **APL** tab.

| File | Upstream |
| ---- | -------- |
| `shaman_elemental.simc` | [`simulationcraft/simc` @ `midnight`: `ActionPriorityLists/default/shaman_elemental.simc`](https://github.com/simulationcraft/simc/blob/midnight/ActionPriorityLists/default/shaman_elemental.simc) |

To refresh the bundled copy:

```bash
curl -sSL https://raw.githubusercontent.com/simulationcraft/simc/midnight/ActionPriorityLists/default/shaman_elemental.simc \
  -o assets/apl/shaman_elemental.simc
flutter test   # the APL tests flag conditions the parser or sandbox can't handle
```

SimulationCraft is licensed under the GNU GPL v3.
