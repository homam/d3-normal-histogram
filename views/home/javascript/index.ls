prelude = require('prelude-ls')
{Obj,map, filter, each, find, fold, foldr, fold1, all, flatten, sum, group-by, obj-to-pairs, partition, join, unique, sort-by, reverse} = require 'prelude-ls'

listOfSubscriptioMethods = [{"id":0,"name":"Unknown", label: "??"},{"id":11,"name":"WAP", label: "DW"},{"id":1,"name":"sms", label: "SMS"},{"id":2,"name":"smsto", label: "STO"},{"id":3,"name":"mailto", label: "MTO"},{"id":7,"name":"SMS_WAP", label: "MO"},{"id":8,"name":"LINKCLICK", label: "LKC"},{"id":6,"name":"JAVA_APP", label: "JA"},{"id":4,"name":"LinkAndPIN", label: "LnP"},{"id":5,"name":"LinkAndPrefilledPIN", label: "LnPP"},{"id":9,"name":"WAPPIN", label: "Pin"},{"id":10,"name":"GooglePlay", label: "GP"}]

# utility functions region

format-date = d3.time.format('%Y-%m-%d')

pow = Math.pow
pow2 = (n) -> Math.pow n, 2
sqrt = Math.sqrt

# end utility functions region

treeUiTypes = {
	'tree-long-branches': tree-long-branches
	'tree-map': tree-map,
	'devices-histogram': devices-histogram
}

treeChart = devices-histogram(screen.width-10,1000) #tree-map(1300,500) # tree-long-branches(1000,1000) 


$ ->
	update-stats-at-footer = (node) ->

		# allMethodsSummary :: {visits, subscribers, conversion}
		allMethodsSummary = fold ((acc, a) -> {visits: a.visits+acc.visits, subscribers: a.subscribers+acc.subscribers}), {visits: 0, subscribers: 0}, node.stats
		allMethodsSummary.conversion = allMethodsSummary.subscribers/allMethodsSummary.visits
		
		$summarySpan = d3.select('.all-methods-summary').selectAll('span').data(obj-to-pairs allMethodsSummary)
		$summarySpan.enter().append('span').attr('class',->it[0])
		$summarySpan.text(-> (if 'conversion' == it[0] then d3.format('.1%') else d3.format(','))  it[1])


		# render stats for each subscription method
		$li = d3.select('.node-methods-stats').selectAll('li').data(node.stats)
		$liEnter = $li.enter().append('li')
		$li.exit().remove()
		render-method-stats = (className, text) -> 
			$liEnter.append("span").attr("class", className)
			$li.select("span.#{className}").text(text)
		each (-> render-method-stats it, (m) -> m[it]), ['method', 'visits', 'subscribers']
		render-method-stats 'conversion', (m) -> d3.format('.1%')(if m.visits == 0 then 0 else (m.subscribers / m.visits))
		$li.transition().duration(200).style("opacity", (-> 
			ratio = it.visits / allMethodsSummary.visits
			d3.scale.linear().domain([0,0.33]).range([0.2,1]).clamp(true)(ratio)
		))
			#if it.visits < (allMethodsSummary.visits * 0.1) then 0.5 else 1))


	all-parents = (n, list) ->
		| !n._parent => [n] ++ list
		| otherwise => all-parents(n._parent, list) ++ [n] ++ list

	#  event handler: node clicked
	$(window).on "tree/node-selected", (.., node, keepBreadcrumb = false)->

		# create a test dialog:
		$('#create-a-test').unbind('click').one 'click', -> 
			if !!$('#chosen-tests').val() then show-conclude-a-test-dialog(node) else show-create-a-test-dialog(node)


		update-stats-at-footer node

		if !keepBreadcrumb
			$('.stats h2').html('')
			names = (all-parents node, [])
			$a = d3.select('.stats h2').selectAll('a').data(names)
			.enter().append('a').text(->name-node(it))
			.on('click', -> $(window).trigger("tree/node-selected", [it, true]))

		
		
$ ->
	root = null

	change-tree-ui = (type) ->
		$(".tree").html('')

		treeChart := treeUiTypes[type](screen.width-10,1000)
		update-tree-from-ui!

	update-tree-from-ui = ->
		if !root.stats then
			#$(".tree").html('Nothing!')
			console.log 'nothing!'
			return

		lastTreeId = 0
		add-treeId-to-node = (n) -->
			| !n.children or n.children.length == 0 => n.treeId = ++lastTreeId;
			| otherwise => n.treeId = ++lastTreeId; each (add-treeId-to-node), n.children

		add-treeId-to-node root


		add-parent-to-node = (parent, n) -->
			n._parent = parent;
			if !!n.children
				n.children = map (add-parent-to-node n), n.children
			n


		find-method = (name, stats) ->
			(find (-> it.method == name), stats) or {visits: 0, subscribers: 0}
		
		calc-conv = (m) ->
			if m.visits == 0 then 0 else m.subscribers/m.visits

		# in utils.ls
		stndDev-of-conversion-for-method = (methodName, node) -> 
			sqrt fold-real-nodes node, ((n, acc) ->
				if !!n.children and n.children.length>0
					return 0
				
				method = find-method methodName, n.stats
				rootMethod = find-method methodName, node.stats

				v = pow2(calc-conv(method) - calc-conv(rootMethod)) * method.visits/rootMethod.visits

				return v+acc
			), 0


		[filteredRoot, selected-stats] = filter-tree hard-clone(root), $('#chosen-methods').val(), $('#chosen-methods-orand').is(':checked'), true, parseInt($('#kill-children-threshold').val())
		untree = do -> filter (-> !!it) <| fold-real-nodes filteredRoot, ((n, acc) -> [n] ++ acc), null



		# find a node select
		$wurflSelect = $('#chosen-find-wurfl-node')
		currentWurflNode = $wurflSelect.val!

		$option = d3.select('#chosen-find-wurfl-node').selectAll('option').data([{}] ++ untree)
		$option.enter().append('option')
		$option.text(-> it.device).attr('value', -> it.device)
		$option.exit().remove()

		$wurflSelect.select2({width: 'element', allowClear: true})
		$wurflSelect.on 'change', ->
			if this.selectedIndex > 0
				node = this.options[this.selectedIndex].__data__
				$(window).trigger("tree/node-selected", [node, true])

		$wurflSelect.select2('val', currentWurflNode)


		treeChart.update-tree (add-parent-to-node null, filteredRoot), selected-stats


		# delay updating the chart till after it is rendered
		if !!$wurflSelect.val()
			$wurflSelect.change()


	val = (cssSelector) -> $(cssSelector).val() || '-'

	re-root = (url) -->
		$('#loading').show()
		setTimeout (-> $('#loading').addClass('visible')), 500
		#url = "data/ae.json"
		console.log '*** ', url
		r <- $.get url
		root := r
		update-tree-from-ui!
		$('#loading').removeClass('visible')
		setTimeout (-> $('#loading').hide()), 500

	re-root-again = null

	re-root-country = ->
		$('#chosen-superCampaigns').select2('val', '')

		url = if !$('#chosen-tests').val() or parseInt($('#chosen-tests').val()) == 0 then
			"/api/stats/tree/#{val('#fromDate')}/#{val('#toDate')}/#{val('#chosen-countries')}/#{val('#chosen-refs')}/0"
		else
			"/api/test/tree/#{val('#chosen-tests')}/#{val('#fromDate')}/#{val('#toDate')}/#{val('#chosen-countries')}/#{val('#chosen-refs')}"

		re-root-again := re-root-country
		re-root url

	re-root-superCampaign = ->
		$('#chosen-countries, #chosen-refs, #chosen-tests').select2('val','')

		url = "/api/stats/tree-by-superCampaign/#{val('#fromDate')}/#{val('#toDate')}/#{val('#chosen-superCampaigns')}/#{val('#chosen-refs')}/0"

		re-root-again := re-root-superCampaign
		re-root url

	re-root-again = re-root-country	


	# header

	# D3Selection <select> -> D3Selections <option>
	populate-methods = ($d3select) ->
		$d3select.selectAll('option').data(listOfSubscriptioMethods)
		.enter().append('option').text(-> it.name)
	
	# header
	populate-methods(d3.select('#chosen-methods'))
	$('#chosen-methods').select2({width: 'element'}).change(->update-tree-from-ui())


	# dialog
	populate-methods(d3.select('#chosen-create-test-methods')).attr('value', -> it.id)
	$('#chosen-create-test-methods').select2({width: 'element'})

	$('#chosen-methods-orand').change ->
		$('#kill-children-threshold').val(if $(this).is(':checked') then 100 else 0)
		update-tree-from-ui!

	$('#kill-children-threshold').change(->update-tree-from-ui!)


	populate-chosen-select-by-data = ($select, data, defaultValue = null) ->
		d3.select($select[0]).selectAll('option').data(data)
		.enter().append('option').attr("value", -> it.id).text(-> it.name)
		$select2 = $select.select2({width: 'element', allowClear: true})
		if defaultValue is not null and typeof(defaultValue) != "undefined"
			$select2.select2('val', defaultValue)
		[$select, data]

	# callback :: ($jQuerySelect) -> void
	populate-chosen-select = ($select, url, mapFunc, defaultValue, callback) ->
		data <- $.get url
		data  = mapFunc data
		populate-chosen-select-by-data $select, data, defaultValue
		callback $select, data


	
	(_, countries) <- populate-chosen-select($('#chosen-countries').on('change', -> re-root-country!), 'http://mobitransapi.mozook.com/devicetestingservice.svc/json/GetAllCountries', 
		((countries) -> [{}] ++ countries), 2) # select uae as the intial country TODO: get it from query string

	# dialog
	populate-chosen-select-by-data $('#create-a-test-dialog .countries'), countries



	do ->
		_ <- populate-chosen-select($('#chosen-refs').on('change', -> re-root-again!), 'http://mobitransapi.mozook.com/devicetestingservice.svc/json/GetRefs',
			((refs)-> refs[0] = {}; refs), '') # TODO: get default ref from QueryString

		_ <- populate-chosen-select($('#chosen-superCampaigns').on('change', -> re-root-superCampaign!), 'http://mobitransapi.mozook.com/devicetestingservice.svc/json/GetSuperCampaigns',
			((superCampaigns)->  [{}] ++ (filter (-> it.name.indexOf('[') != 0), superCampaigns)), '') # TODO: get default ref from QueryString


		_ <- populate-chosen-select($('#chosen-tests').on('change', -> re-root-again!), '/api/tests/true',
			((tests)->  [{}] ++ [{id: t.id, name: "#{t.device} (#{t.id})"} for t in tests]), '')


	now = new Date()
	$('#fromDate').attr("max", format-date new Date(now.valueOf()-1*24*60*60*1000))
	.val(format-date new Date(now.valueOf()-2*24*60*60*1000))
	.change(->re-root-again!)

	$('#toDate').attr("max", format-date new Date(now.valueOf()+2*24*60*60*1000))
	.val(format-date now)
	.change(->re-root-again!)

	$('#chosen-tree-ui-type').select2().change(-> change-tree-ui $(this).val())




	re-root-again!


	# end $()



show-dialog = ($selector) ->
	hide-dilaog = ->
		console.log 'hiding dialog'
		$selector.removeClass('visible')
		setTimeout (-> $selector.hide!), 500

	$selector.find('.step').hide()
	$selector.find('.step-1').show()
	$selector.show!
	setTimeout (-> $selector.addClass('visible')), 500

	$selector.find('.dialog-close').one 'mousedown', -> hide-dilaog!

	hide: hide-dilaog


show-create-a-test-dialog = (node) ->
	dialog = show-dialog $('#create-a-test-dialog')
	$('.wurflId').text(name-node node)
	$('#create-a-test-dialog .commit').one 'click', ->
		countries = $('#chosen-create-test-countries').val()
		methods = $('#chosen-create-test-methods').val()
		if !!countries and !!methods and !!countries.length and !!methods.length
			url = "http://mobitransapi.mozook.com/devicetestingservice.svc/json/CreateDeviceTest?wurfl_id=#{node.id}&methods=#{methods}&countries=#{countries}"
			console.log "create-a-test url << ", url
			result <- $.get url
			console.log 'test created', result
			$('#create-a-test-dialog .step-1').hide()
			$('#create-a-test-dialog .step-2').show()
			$('#create-a-test-dialog .step-2 .results').text("Test Created, ID = #{result[0].id}")


show-conclude-a-test-dialog = (node) ->
	dialog = show-dialog $('#conclude-a-test-dialog')
	$('.wurflId').text(name-node node)
	# stats :: [{method, visits, subscribers}]
	stats = sort-by (-> it.conversion), node.stats

	# all devices support DirectWAP (highest priority) and PIN and MO (lowest priority)
	# [WAP] ++ stats ++ [WAPPIN, SMS_WAP]
	make-stat = (method, visits, subscribers) -> 
		if (filter (-> it.method == method), stats).length == 0
			[{method: method, visits: visits, subscribers: subscribers}]
		else
			[]
	stats = make-stat('WAP', 1, 1) ++ stats ++ make-stat('WAPPIN', 1, 1) ++ make-stat('SMS_WAP', 1, 1)

	testId = parseInt $('#chosen-tests').val()

	$dialog = $('#conclude-a-test-dialog')
	$dialog.find('.commit').one 'click', ->
		methodNames =  map (-> it.method), stats
		methodIds = [m.id for name in methodNames
					for m in listOfSubscriptioMethods
					when name == m.name
		]
		console.log "names", methodNames
		methoIdsString = join ',', methodIds
		console.log methodIds, methoIdsString

		url = "http://mobitransapi.mozook.com/devicetestingservice.svc/json/ConcludeDeviceTest?test_id=#{testId}&wurfl_id=#{node.id}&methods=#{methoIdsString}"
		result <- $.get url # reuslt :: String
		console.log result
		$dialog.find('.step-1').hide()
		$dialog.find('.step-2').show()
		$dialog.find('.step-2 .results').text("Test Concluded")


	render = ->
		console.log stats

		$li = d3.select("ol.methods").selectAll('li.method').data(stats)
		$liEnter = $li.enter().append('li').attr('class', 'method')
		$li.exit().remove()

		render-method-stats = (className, text) -> 
			$liEnter.append("span").attr("class", className)
			$li.select("span.#{className}").text(text)
		each (-> render-method-stats it, (m) -> m[it]), ['method', 'visits', 'subscribers']
		render-method-stats 'conversion', (m) -> d3.format('.1%')(if m.visits == 0 then 0 else (m.subscribers / m.visits))
		$liEnter.append('span').attr('class', 'close').text('x').on 'click', (d)->
			stats := filter (-> it.method != d.method), stats
			render!

		$("ol.methods").sortable!

	render!


# fot test only
#setTimeout (->show-conclude-a-test-dialog {"brand":"Nokia","device":"nokia_x2_02_ver1","fall_back":"nokia_generic_series40_dp60","id":14925,"ishtml5":"none","model":"X2-02","os":"","stats":[{"method":"JAVA_APP","visits":3238,"subscribers":269},{"method":"mailto","visits":1992,"subscribers":120},{"method":"smsto","visits":1824,"subscribers":0}],"version":"","children":[{"brand":"Nokia","device":"nokia_x2_02_ver1_subovibrsr","fall_back":"nokia_x2_02_ver1","id":15330,"ishtml5":"none","model":"X2-02","os":"","stats":[{"method":"JAVA_APP","visits":1846,"subscribers":65},{"method":"mailto","visits":780,"subscribers":0},{"method":"smsto","visits":624,"subscribers":0}],"version":"","children":[],"treeId":5,"_parent":null,"selectedStats":[3250,65,0.02],"x":4,"y":3250,"y0":0,"parent":null},{"brand":"Nokia","device":"nokia_x2_02_ver1","fall_back":"nokia_generic_series40_dp60","id":14925,"ishtml5":"none","model":"X2-02","os":"","stats":[{"method":"JAVA_APP","visits":1392,"subscribers":204},{"method":"mailto","visits":1212,"subscribers":120},{"method":"smsto","visits":1200,"subscribers":0}],"version":"","children":[],"treeId":6,"_parent":null,"selectedStats":[3804,324,0.08517350157728706],"x":19,"y":3804,"y0":0,"parent":null}],"treeId":4,"_parent":null,"parent":null} ), 1000