prelude = require('prelude-ls')
{Obj,map, filter, each, find, fold, foldr, fold1, all, flatten, sum, group-by, obj-to-pairs, partition, join, unique, sort-by, reverse, take, id, mean} = require 'prelude-ls'


# utility functions region

format-date = d3.time.format('%Y-%m-%d')

pow = Math.pow
pow2 = (n) -> Math.pow n, 2
sqrt = Math.sqrt
floor = Math.floor
random = Math.random
round = Math.round

# end utility functions region




# sample :: [Bool] -> [Bool]
sample = (size, ds) --> map (-> ds[it]) <| [floor(random! * ds.length) for i in [1 to size]]

# conversion :: [Bool] -> Float
conversion = (ds) -> (/ds.length) . (.length) . (filter (->it)) <| ds



margin = {top: 10, right: 30, bottom: 30, left: 80}
width = 960 - margin.left - margin.right
height = 500 - margin.top - margin.bottom


raw <- d3.csv 'public/uae.csv'

# rdata :: [Bool]
rdata = [subsribed != 'NULL' for {vid, sid:subsribed} in raw]

conversionRate = conversion rdata

console.log conversionRate




$svg = d3.select('.graph').append('svg')
.attr('width', width + margin.left + margin.right)
.attr('height', height + margin.top + margin.bottom)
.append('g')
.attr('transform', "translate(#{margin.left}, #{margin.top})")
$svg.append('g').attr('class', 'x axis').attr('transform', "translate(0, #{height})")
$svg.append('g').attr('class', 'y axis').attr('transform', "translate(0, 0)")

$bars  = $svg.append('g').attr('class', 'bars')

add-line = (className, color) ->
	$svg.append('g').attr('class', className).append('rect').attr('width', 4).attr('x', -2).attr('height', -> height + margin.bottom).style({'fill': color, 'opacity': 0.7})

add-line 'mu', '#FD5823'
add-line 'ciRight', '#FFCC00'
add-line 'ciLeft', '#FFCC00'


render = (sampleSize, repeats, numberOfBins, xMax, callback = $.noop) ->

	# parallel
	sampled <- new Parallel([rdata, sampleSize, repeats]).spawn(([input, size, repeats]) ->
		floor = Math.floor
		random = Math.random
		conversion = (ds) -> ds.filter(-> it).length / ds.length
		sample = (ds) -> [floor(random! * ds.length) for i in [1 to size]].map(-> ds[it])

		[conversion(sample input) for i in [1 to repeats]]
	).then

	# synchronous and pettier
	#sampled = [(conversion . sample sampleSize) rdata for i in [1 to repeats]]

	ci = sqrt(conversionRate * (1 - conversionRate) / sampleSize)

	console.log 'render', sampleSize, repeats, (mean sampled), ci

	x = d3.scale.linear().domain([0, xMax ? (d3.max sampled)]).range([0, width])

	data = d3.layout.histogram().bins(x.ticks(numberOfBins)) sampled

	y = d3.scale.linear().domain([0, (d3.max data, (.y))]).range([height,0])


	# mu line
	$svg.select('g.mu').attr('transform', "translate(#{x(conversionRate)}, #{-margin.top})")
	$svg.select('g.ciRight').attr('transform', "translate(#{x((conversionRate + ci))}, #{-margin.top})")
	$svg.select('g.ciLeft').attr('transform', "translate(#{x((conversionRate - ci))}, #{-margin.top})")
	

	$bar = $bars.selectAll('.bar').data(data)
	$barEnter = $bar.enter().append('g').attr('class', 'bar')
	$bar.exit().remove()
	$bar.transition().duration(500).attr('transform', -> "translate(#{x(it.x)}, #{y(it.y)})")

	$barEnter.append('rect')
	$bar.select('rect')
	.transition().duration(500)
	.attr('x', 1)
	.attr('width', x(data[0].dx)-1)
	.attr('height', -> height - y(it.y))

	$barEnter.append('text').attr('dy', '.75em').attr('y', 6).attr("text-anchor", "middle")
	$bar.select('text').attr('x', x(data[0].dx)/2).text(-> d3.format('%') it.y/repeats)



	xAxis = d3.svg.axis().scale(x).orient('bottom').tickFormat(d3.format '.2%')
	$svg.selectAll('.x.axis').transition().duration(500).call(xAxis)

	yAxis = d3.svg.axis().scale(y).orient('left').tickFormat(-> (d3.format '%') (it/repeats))
	$svg.selectAll('.y.axis').transition().duration(500).call(yAxis)

	callback!

render-input = (callback = $.noop) ->
	render parseInt($('footer input[data-value=sampleSize]').val()),
	parseInt($('footer input[data-value=repeats]').val()),
	parseInt($('footer input[data-value=numberOfBins]').val()),
	parseFloat($('footer input[data-value=xMax]').val()/1000),
	callback



# footer
$divEtner = d3.select('footer').selectAll('div').data(['sampleSize', 'repeats', 'numberOfBins', 'xMax']).enter().append('div')
	..append('label').attr('for', -> it).text(-> it)
	..append('input').attr('type', 'range').attr('placeholder', -> it).attr('data-value', -> it)
	..append('span').attr('class', 'value').attr('data-value', -> it)

# footer controls default values
set-val = ($t, v, f = id) -> 
	$t.val(v)
	$t.attr('data-last', v)
	$t.parent().find('span').text(f v)
	$t.on 'change', $.throttle(500, false, ->
		$this = $(this)
		value = $this.val() 
		$this.parent().find('span').text(f value)
		render-input!
	)


set-val $('footer input[data-value=sampleSize]').attr('min', raw.length * 0.0001).attr('max', raw.length * 0.01), (raw.length * 0.001)
set-val $('footer input[data-value=repeats]').attr('min', 10).attr('max', 5000), (100)
set-val $('footer input[data-value=numberOfBins]').attr('min', 5).attr('max', 40), (20)
set-val $('footer input[data-value=xMax]').attr('min', (conversionRate)*1000).attr('max', (conversionRate)*3*1000), ((conversionRate)*2*1000), (d3.format '.2%') . (/1000)

# footer inputs event handlers

# draw it!
render-input!