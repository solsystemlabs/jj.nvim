# Graph-Aware Wrapping Research

## Context
During development, we attempted to implement graph-aware text wrapping that would preserve jj's graph structure when long lines wrap. This document captures our findings for future reference.

## The Challenge
jj log output contains complex ASCII graph structures:
```
│ │ │ │ │ │ ◆  wxtxtqyv ewatson@visiostack.com 2025-06-25 10:38:51 c87936c7
│ │ │ │ │ │ │  feat: Change buttons for historical
```

When wrapping, we wanted to maintain proper graph continuation:
```
│ │ │ │ │ │ ◆  wxtxtqyv ewatson@visiostack.com 2025-06-25
│ │ │ │ │ │ │  10:38:51 c87936c7
│ │ │ │ │ │ │  feat: Change buttons for historical
```

## Graph Complexity Discovered

### Simple Cases (what we initially planned for):
- `@  commit` → continuation: `│  wrapped content`
- `│ ○  commit` → continuation: `│ │  wrapped content`

### Complex Real-World Cases:
- 6+ levels deep: `│ │ │ │ │ │ ◆  commit`
- Complex merges: `├───────────╯  feat: description`
- Elided sections: `│ ~` and `~  (elided revisions)`
- Conflict states: `×  commit conflict`
- Multi-character connectors: `╭───────────┤`

## Proposed Solutions Evaluated

### 1. Two-Pass Approach
- Pass 1: `jj log -T ""` (graph only)
- Pass 2: `jj log -T "template"` (data only)
- **Issue**: Synchronization complexity, performance concerns

### 2. Single-Pass Graph Parsing
- Parse `jj log` output for both graph + data
- Extract graph prefix per line
- Calculate continuation patterns
- **Issue**: Complex state machine needed

### 3. Leverage Existing Graph (chosen direction)
- Extract graph prefix from each line using regex
- Count active `│` characters
- Use pattern: `graph_prefix + │ + spacing` for continuations
- **Issue**: Still complex for deep branching

## Key Insights

1. **jj doesn't do graph-aware wrapping either** - native jj log in narrow terminals also breaks graph structure
2. **Graph state is complex** - 6+ levels, elided sections, multiple connector types
3. **Regex approach viable** - Pattern: `^([│├─╮╯╭┤~\s]*[@○◆×])?(.*)` could work
4. **Column counting method** - Count `│` characters to determine depth

## Implementation Approach (if revisited)

```lua
-- Extract graph prefix and calculate continuation
local function get_graph_continuation(line)
  local graph_prefix = line:match("^([│├─╮╯╭┤~%s]*)")
  local vertical_bars = 0
  for _ in graph_prefix:gmatch("│") do
    vertical_bars = vertical_bars + 1
  end
  return string.rep("│ ", vertical_bars + 1)
end
```

## Decision
**Reverted to window wrapping** for pragmatic reasons:
- jj native behavior doesn't preserve graph either
- Implementation complexity vs. benefit trade-off
- Can be revisited when time permits

## Files Modified During Research
- `/lua/jj-nvim/core/renderer.lua` - removed `wrap_line_with_graph()`, `wrap_clean_text()`, `reconstruct_with_colors()`
- `/lua/jj-nvim/config.lua` - `wrap = true` (already enabled)

## Future Considerations
If re-implementing:
1. Start with simple cases (1-2 levels deep)
2. Build comprehensive test suite with complex graph patterns
3. Consider performance impact of regex parsing
4. Handle elided sections and conflict states
5. Ensure proper ANSI color preservation