{Obj,map, filter, each, find, fold, foldr, fold1, all, flatten, sum, group-by, obj-to-pairs, partition, join, unique} = require 'prelude-ls'

exports = exports or this
# node: any node in the tree
# func: folding function :: (Node, Acc) -> Acc
# seed :: Acc
exports.fold-real-nodes = (node, func, seed) ->
	| node.children.length == 0 => func(node, seed)
	| otherwise => 
		fold ((ac, a) -> fold-real-nodes(a, func, ac)), seed, node.children

each-tree-node = (func, node) -->
	func(node)
	if !!node.children and !!node.children.length
		each (each-tree-node func), node.children

exports.each-tree-node = each-tree-node


hard-clone = -> JSON.parse JSON.stringify it
exports.hard-clone = hard-clone


trace = (v) ->
	console.log v
	v
exports.trace = trace


sor = (a,b) -> if (!!a and a.length > 0 and a != ' ') then a else b
exports.sor = sor


exports.name-node = (n) -> n.device `sor` n.brand `sor` n.os `sor` ''



# methodSelector :: Method -> Bool
# prop :: String
_sum-stats = (methodSelector, prop, node) --> fold1 (+) <| ([m[prop] for m in node.stats when methodSelector(m.method)])
sum-visits = (methodSelector, node) --> 	_sum-stats methodSelector, 'visits', node
sum-subscribers = (methodSelector, node) --> _sum-stats methodSelector, 'subscribers', node


# update all nodes with accumulated stats info
update-all-nodes = (updater, node) -->
	| node.children.length == 0 => node
	| otherwise => (map (update-all-nodes updater), node.children)
	updater node


# remove children that match the criteria
# criteria :: Node -> Bool
kill-children-by-criteria = (criteria, node) -->
	| node.children.length == 0 => node
	| otherwise => 
		node.children = filter (-> criteria it), node.children
		(map (kill-children-by-criteria criteria), node.children)
	node

# remove children with low number of visits
# visitsSelector :: Node -> Number
kill-children = (minVisits, visitsSelector, node) --> 
	kill-children-by-criteria (-> visitsSelector(it) > minVisits), node


# (String -> Bool), Node -> [Visits, Subscribers, Conversion]
stats = (methodFilter, node) ->
	v = sum-visits methodFilter, node
	s = sum-subscribers methodFilter, node
	c = if v == 0 then 0 else s/v
	[v,s,c]

exports.node-selected-stats = stats

# this function changes the input root
exports.filter-tree = (root, selectedSubscriptionMethods, selectedSubscriptionMethodsOr, excludeDesktop, killChildrenThreshold = 100) ->

	if excludeDesktop
		root.children = filter (-> it.os != 'Desktop'), root.children

	# [String] -> (String -> Bool)
	create-method-filter = (selectedMethods) -> (method) -> method in selectedMethods

	# all if selectedSubscriptionMethods is null
	# String -> Bool
	selected-method-filter = if !selectedSubscriptionMethods then (->true) else create-method-filter selectedSubscriptionMethods

	# Node -> Number
	selected-visits = sum-visits selected-method-filter

	# Node -> Number
	selected-subscribers = sum-subscribers selected-method-filter

	# Node -> [Visits, Subscribers, Conv]
	selected-stats = (node) -> stats selected-method-filter, node


	# 	[totalVisitsSelected,totalSubscribersSelected,convAverageSelected] = selected-stats root

	# convStnDevSelected = fold-real-nodes root, ((n, acc) -> 
	# 	[v,s,conv] = selected-stats n
	# 	acc + sqrt(pow(conv - convAverageSelected, 2))*v/totalVisitsSelected), 0




	# end selected methods region

	if selectedSubscriptionMethodsOr
		root = kill-children killChildrenThreshold, selected-visits, root # or
	else
		root = kill-children-by-criteria ((node) ->
			all (->it), [((find (-> it.method == m), node.stats).visits > killChildrenThreshold) for m in selectedSubscriptionMethods]
		), root # and

	[root, selected-stats]