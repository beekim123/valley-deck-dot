extends RefCounted
## Pure D0 rule seed: transactional pre-deduction; input is never mutated.
## Costs and balances come from content/state, not presentation constants.
static func reserve(balance: Dictionary, cost: Dictionary) -> Dictionary:
	for resource: String in cost:
		if not cost[resource] is int or cost[resource] < 0:
			return {"ok": false, "reason": "invalid_cost", "balance": balance.duplicate(true)}
		if int(balance.get(resource, 0)) < int(cost[resource]):
			return {"ok": false, "reason": "insufficient_resource", "balance": balance.duplicate(true)}
	var remaining := balance.duplicate(true)
	for resource: String in cost:
		remaining[resource] = int(remaining.get(resource, 0)) - int(cost[resource])
	return {"ok": true, "reason": "", "balance": remaining}

static func refund(balance: Dictionary, reserved: Dictionary) -> Dictionary:
	var result := balance.duplicate(true)
	for resource: String in reserved:
		result[resource] = int(result.get(resource, 0)) + int(reserved[resource])
	return result
