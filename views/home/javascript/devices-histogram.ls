prelude = require('prelude-ls')
{Obj,map, filter, each, find, fold, foldr, fold1, all, flatten, sum, group-by, obj-to-pairs, partition, join, unique,sort-by, maximum, minimum} = require 'prelude-ls'

pow = Math.pow
sqrt = Math.sqrt
floor = Math.floor
round = Math.round


exports = exports or this

exports.devices-histogram = (width = 1000, height = 1000) ->
	height = 600
	width= 1000

	bins = 20
	margins = [20, 50, 50, 20]
	x = d3.scale.ordinal().rangeRoundBands([0, width - margins[1] - margins[3]]).domain([0 to bins-1])
	y = d3.scale.linear().range([0, height - margins[0] - margins[2]])	
	$svg = d3.select(".tree").append("svg")
	.attr("class", "devices-histogram")
	.attr("width", width).attr("height", height).append("g").attr("transform", "translate(#{margins[3]},#{height - margins[2]})")

	color = d3.scale.category10();

	# root :: Node
	# selected-stats :: Node -> [Visits, Subscribers, Conv]
	# selectedSubscriptionMethods :: [String]
	# selectedSubscriptionMethodsOr :: Bool
	# call this function to update the UI and the tree graphics
	update-tree = (root, selected-stats) ->

		# utility for animating transition
		transition = (node) -> node.transition().duration(500)

		# convert the tree to an array
		untree = do -> map (-> it.selectedStats = selectedStats(it); it) <| filter (-> !!it and !!it.stats) <|
			fold-real-nodes root, ((n, acc) -> [n] ++ acc), null

		convMax = (maximum <| map (-> it.selectedStats[2]) <| untree)
		convMin = 0
		binSize = convMax/(bins-1)

		

		make-y0 = ->
			last = 0
			(d) ->
				current = last
				last := d.y + last
				return current


		# blocks :: [ name, values :: [Node :: {x, y, y0, ...}] ]
		blocks = do ->
			((input) -> [{name: t.name, values: (map (->it.y0 = y0(it); it), t.values)} for [t, y0] in input]) <|
			# create new y0 makers for each block
			map (-> [it, make-y0()]) <|
			# sort the y values so the larger block go to the bottom
			((input) -> [{name:parseInt(name), values:(sort-by (->-it.y), values)} for [name, values] in input]) <| 
			obj-to-pairs <| group-by (-> it.x) <|
			map (-> 
				it.x = (round <| it.selectedStats[2] / binSize);
				it.y = it.selectedStats[0];
				it) <| untree
		
		# fill the empty bins
		blocks = do -> 
			map ((b)->{name:b, values:((find (-> it.name == b), blocks) or {values:[]}).values}) <| [0 to bins-1]


		y.domain([0, do -> maximum <| map (-> it.y + it.y0) <| flatten <| map (-> it.values) <| blocks])


		$bin = $svg.selectAll('g.bin').data(blocks)
		$binEnter = $bin.enter().append('g').attr('class', 'bin')
		$bin.exit().remove()
		$bin.attr("transform", -> "translate(#{x(it.name)},#{margins[0]})")

		$binEnter.append('text').attr('class', 'bin-label')
		.attr("text-anchor", "middle").attr("dy", "1em")
		$bin.select('text.bin-label').attr("x", x.rangeBand() / 2).attr("y", 0).text(-> d3.format('.1%')(it.name * binSize))


		$device = $bin.selectAll('g.device').data(-> it.values)
		$deviceEnter = $device.enter().append('g').attr('class', 'device')
		.on('mousedown', -> $render-node-methods-stats it)
		$deviceEnter.append('rect')
		$device.select('rect').attr('class', -> "node-#{it.treeId}")
		.attr("width", -> x.rangeBand()).attr("height", -> y(it.y))
		.attr("x", 0).attr("y", -> -y(it.y0) - y(it.y))
		.style("fill", -> color(it.os))
		$device.exit().remove()
		





		# render stats in footer
		$render-node-methods-stats = (node) ->
			$(window).trigger("tree/node-selected", [node])

		#$render-node-methods-stats root


	$(window).on "tree/node-selected", (.., node) ->
		d3.selectAll('rect.selected').classed('selected', false) # deselect currently selected one
		each-tree-node (-> d3.select(".node-#{it.treeId}").classed('selected', true)), node

	# return
	{	
		$svg,
		update-tree
	}

