# Flows

## 1. Worker Request Flow

```text
stdin JSON
  -> json_worker.lua
  -> entry.bootstrap / entry.context
  -> runtime.session.new(...)
  -> bootstrap.launch(...)
  -> session:runUntilSettled(...)
  -> transport.json_stdio.dispatchRequest(session.api, request)
  -> stable api method
  -> service
  -> repo
  -> pob adapter / upstream PoB object graph
  -> result
  -> transport response envelope
  -> stdout JSON
```

## 2. Stable Method Dispatch Flow

```text
request.method
  -> assert request envelope
  -> assert method is in get_api_surface().stable
  -> normalize params
  -> optional stateless preload (build_xml / build_code)
  -> dispatch stable method
  -> wrap result with meta
```

## 3. Legacy Script Flow

```text
headless_bridge.lua
  -> bootstrap environment
  -> create session
  -> install legacy helpers
  -> load POB_HEADLESS_SCRIPT
  -> helper calls PoBHeadless.<method>
  -> PoBHeadless delegates to:
     - stable root methods, or
     - flattened experimental methods
  -> session settle/finalize
```

## 4. Load Build + Summary Flow

```text
load_build_xml/load_build_code
  -> build service
  -> build repo
  -> main:SetMode("BUILD", ...)
  -> session frame advance
  -> build object refreshed
  -> get_summary
  -> stats service
  -> stats repo
  -> summary payload
```

## 5. Item Compare Flow

```text
compare_item_stats
  -> items service
  -> parse candidate item
  -> capture before summary/stats
  -> simulate/equip through items repo
  -> build_runtime recalculation
  -> capture after summary/stats
  -> compute delta payload
  -> restore original state when needed
```

## 6. Tree Simulation Flow

```text
simulate_node_delta
  -> tree service
  -> repo tree snapshot
  -> build target tree
  -> apply simulated allocation/masteries
  -> build_runtime recalculation
  -> compare before/after stats
  -> restore snapshot
```

## 7. Error Mapping Flow

```text
repo/service returns nil, "string error"
  -> transport.error.fromUpstream(...)
  -> error.code
  -> error.retryable
  -> optional error.details
  -> JSON error response
```
