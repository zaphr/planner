$(document).ready ->
    $('.planner').hide()
#    planner.page.block_all_non_chrome_browsers()
    planner.init()
    $('button').button()
    planner.page.setup_shortcuts()

    $('#place').submit ->
      search_term = $('#place_term').val()
      planner.main_controller.show_places(search_term)
      return false

window.planner =
    init: ->
        planner.main_controller = new planner.controllers.Main()
        Backbone.history.start()

    type_labels : {
        'Eat': 'Something to eat',
        'Sleep': 'Somewhere to sleep',
        'See': 'Something to see',
        'Shop': 'Somewhere to shop',
        'Night': 'Something at night',
        'Do': 'Something to do',
        'Anything' : 'Anything'
    }

    models : {}

    collections : {}

    controllers : {}

    views : {}

planner.user =
    latitude: null
    longitude: null
    place_url : null
    place: null
    marker: null


planner.controllers.Main = Backbone.Controller.extend

    routes: {
        "location"   : "get_location"
        "things/:type" : "list",
        "add/:id" : "add",
        "show/:id" : "show",
        "get_day" : "get_day",
        "places/:id" : "set_starting_location",
        "show_map" : "show_map",
        "poi_zoom/:id/:display" : "poi_zoom",
        "make_draggable" : "make_draggable",
        "show_all_things" : "show_all_things"},

    show_places: (search_term) ->
      this.get_json '/places/search/' + search_term, (places) =>
        planner.places = new planner.collections.Places(places)
        planner.places.render()

    make_draggable: ->
       elements = ['#thing_detail','#main_list_info', '#heading', '#select_group']
       for element in elements
         $(element).draggable({ delay: 50 }) 

    set_starting_location: (id) ->
      planner.user.place_url = '/places/' + id + '/things'
      planner.user.place = planner.places.get(id)
      planner.places = null
      planner.page.clear_main_list()
      planner.page.render_place_select_map()

    get_day: ->
        latlng = planner.user.marker.getPosition()
        planner.user.latitude = latlng.lat()
        planner.user.longitude = latlng.lng()
        planner.user.marker = null
        this.init()

    poi_zoom: (id, detail) ->

        thing_url = '/things/' + id
        this.get_json thing_url, (thing) ->
           thing = thing[0]
           thing.id = id
           setTimeout( =>
              latlngs = new google.maps.LatLng(thing['latitude'], thing['longitude'])
              marker = new google.maps.Marker
                position: latlngs,
                title: thing['name']

              window.main_map.panTo(latlngs)
              info = "<ul class='rounded' id='info_window'><li>#{thing['name']}</li>"
              if thing['review'] && detail == 'full'
                 info = info + "<li id='info_review'>#{thing['review']}</li>"
              info = info + "</ul>"
              if window.last_window
                last_window.close()
              info_window = new google.maps.InfoWindow
                content: info
              window.last_window = info_window
              setTimeout( ->
                info_window.open(main_map, marker)
                marker.setMap(window.main_map)
                # setTimeout(->
                #  info_window.close()
                # ,2000)
              ,500)
           , 50)  

    show_map: (callback = ->) ->
        latlng = new google.maps.LatLng(planner.user.latitude, planner.user.longitude)

        myOptions = {
          zoom: 16,
          center: latlng,
          mapTypeId: google.maps.MapTypeId.SATELLITE,
          # backgroundColor: '#404142'
        }

        $('#full_map').css({'z-index':'2000', 'width': '100%', 'height': '100%','position':'absolute'})        
        window.main_map = new google.maps.Map(document.getElementById("full_map"), myOptions)
        setTimeout(
          $('#full_map').show()
          window.main_map = new google.maps.Map(document.getElementById("full_map"), myOptions)
          $('#full_map').css({'z-index':'2000', 'width': '100%', 'height': '100%','position':'absolute'})
          callback()
        ,500)

    show_all_things: ->
      this.step_through_mapped_things(this.get_ordered_things(planner.selected_list))

    step_through_itinerary: ->
      this.step_through_mapped_things(planner.itinerary)

    step_through_mapped_things: (collection) ->
      this.show_map =>
        for pos in [1..collection.length]
          do(pos) ->
            setTimeout( ->
              thing = collection.at(pos-1)
              latlngs = new google.maps.LatLng(thing.get('latitude'), thing.get('longitude'))
              marker = new google.maps.Marker
                position: latlngs,
                title: "foo"
              window.main_map.panTo(latlngs)
              info_window = new google.maps.InfoWindow
                content: "<ul class='rounded'><li>#{thing.get('name')}</li></ul>"
              setTimeout( ->
                if window.last_window
                  last_window.close()
                info_window.open(main_map, marker)
                window.last_window = info_window
                marker.setMap(window.main_map)
                setTimeout(->
                 info_window.close() 
                ,2000) 
              ,500)            
            , pos * 2000)      

    get_ordered_things: (collection) ->
      nearby_things = new planner.collections.LocatedThings      
      for pos in [0..collection.length - 1]
        thing = collection.at(0)
        nearby_things.add(thing)
        collection.remove(thing)
        collection.order_by_distance_from(thing.get('latitude'),thing.get('longitude'))
      return nearby_things                

    get_json: (url, callback) ->
      data = sessionStorage.getItem(url)
      if data
        callback(JSON.parse(data))
      else
        $.getJSON url, (json_response) ->
          sessionStorage.setItem(url, JSON.stringify(json_response))
          callback(json_response)

    add: (id) ->
        planner.itinerary.add_thing(id)
        last_item = planner.itinerary.last()
        planner.full_thing_list.order_by_distance_from(last_item.get('latitude'),last_item.get('longitude'))
        this.list(last_item.get('poi_type'))
        this.show(id)
        $('#itinerary').show()

    show: (id) ->
        thing_url = '/things/' + id
        this.get_json thing_url, (thing) ->
            single_thing = thing[0]
            single_thing.id = id
            detail = new planner.views.ThingDetail()
            detail.render(single_thing)

    get_location: ->
        navigator.geolocation.getCurrentPosition (pos) =>
            planner.user.latitude = pos.coords.latitude
            planner.user.longitude = pos.coords.longitude
            this.init()

    init : ->
        planner.full_thing_list = new planner.collections.ThingSummaries
        planner.itinerary = new planner.collections.Itinerary
        this.get_json planner.user.place_url, (thing_list) =>
            $('.planner').show()
            planner.page.clear_main_list()
            planner.page.hide_main_list()
            _.each thing_list, (thing) ->
                if (!_.isEmpty(thing.latitude))
                    thing.poi_type = thing['poi-type']
                    planner.full_thing_list.add(thing)

            planner.full_thing_list.order_by_distance_from(planner.user.latitude,planner.user.longitude)
            this.list('Eat')
            # Fugly hack.. Using 2 requests because google map only displays a single map tile on first request
            this.show(planner.selected_list.at(1).get('id'))
            this.show(planner.selected_list.at(0).get('id'))
            $('#itinerary').draggable({ delay: 50 })

    list : (type) ->
        planner.page.clear_main_list()
        planner.selected_list = new planner.collections.ThingSummaries(planner.full_thing_list.thing_type_of(type))
        planner.selected_list.remove(planner.itinerary.models)
        planner.selected_list.thing_type = type
        planner.page.show_main_list()
        new planner.views.AppView()
        planner.page.update_results_info()


planner.models.ThingSummary = Backbone.Model.extend {

    set_distance_from: (other_latitude, other_longitude) ->
        this.set distance_away: distance_between_points(
                this.get('latitude'), this.get('longitude'),
                other_latitude, other_longitude)
}

planner.models.Place = Backbone.Model.extend {}

planner.collections.Places = Backbone.Collection.extend {

    model: planner.models.Place

    render: ->
      planner.page.clear_main_list()
      this.each (place) ->
          $('#main_list_info').append('<li><a href="#places/' + place.get('id') + '">' +
          place.get('short-name') + ' - ' + place.get('full-name') + '</a></li>')
}

planner.collections.LocatedThings = Backbone.Collection.extend {
    model: planner.models.ThingSummary
}


planner.collections.ThingSummaries = Backbone.Collection.extend {

    model: planner.models.ThingSummary

    order_by_distance_from : (latitude, longitude) ->
        this.each (thing) ->
            thing.set_distance_from(latitude, longitude)
        this.sort()

    comparator : (thing) ->
        return thing.get('distance_away')

    thing_type_of : (thing_type) ->
        if (thing_type == 'Anything')
            return this.models
        return this.filter (thing) ->
            return thing.get('poi_type') == thing_type
}



planner.collections.Itinerary = Backbone.Collection.extend

    model: planner.models.ThingSummary

    add_thing: (thing_id) ->
        thing = planner.full_thing_list.get(thing_id)
        if (this.get(thing_id))
            alert("Your day plan already contains " + thing.get('name'))
        else
            this.add(thing)
            new planner.views.Itinerary({ model: thing})

    last_name: ->
        if (this.length == 0)
            return undefined
        else
            return this.last().get('name')

    add_things: (thing_list) ->
        _.each thing_list, (thing) =>
            this.add_thing(thing)


planner.views.ThingRow = Backbone.View.extend

    tagname: "li"

    render: ->

        template = _.template("<li><a href='#show/{{id}}'>{{distance_away}} <span class='distance'> meters away </span><span class='thing_text'> {{name}}</span>"  +
                "</a><div>" +
                "<a href='#add/{{id}}'>Add</a></div></li>" )

        template(this.model.toJSON())


planner.views.AppView = Backbone.View.extend

    el: $("#main_list_info")

    initialize: ->
        this.add_all()

    add_one: (thing) ->
        view = new planner.views.ThingRow({model: thing})
        this.$("#main_list_info").append(view.render())

    add_all: ->
        planner.selected_list.each(this.add_one)
        $('#main_list_info').append('<li id="savez"></li>')
        $('#main_list_info').append('<li><input type="file" id="input" onchange="handleFiles(this.files)"></li>')
        setup_downloadify();
        # $('#main_list_info').append('<li><a href="#show_map">Show itinerary map</a></li>')

planner.views.Itinerary = Backbone.View.extend

    initialize: ->
        this.render()


    render: ->
        template = _.template("<li><a href='#poi_zoom/{{id}}/summary'>{{planner.itinerary.length}} - {{poi_type}} - {{name}}</a>"+
        "<div><a href='#poi_zoom/{{id}}/full'>Full</a></div>"   +"</li>")
        $("#itinerary").append(template(this.model.toJSON()))


planner.views.ThingDetail = Backbone.View.extend

    render : (thing) ->
        $('#thing_detail').empty()

        $('#thing_detail').append('<li><div id="map"></div></li>')

        items = [thing['name'],
            this.check_value(thing['review']),
            'Opening info: ' + this.check_value(thing['hours']),
            'Location: ' + this.check_value(thing['address']['street']) + ' ' + this.check_value(thing['address']['locality']),
            'Phone: ' + this.check_phone(thing)]
        if (!planner.itinerary.get(thing['id']))
            li_text = thing['name'] + "<div>" +
                "<a href='#add/"+ thing['id'] + "'>Add</a></div>"
            items[0] = li_text

        _.each items, (item) ->
            $('#thing_detail').append('<li>' + item + '</li>')

        planner.page.set_map(thing.latitude, thing.longitude, thing.name)
        $("#dialog" ).show()


    check_value : (value) ->
        if _.isEmpty(value)|| value == 'undefined'
            return ""
        return value

    check_phone : (thing) ->
        try
            return this.check_value thing['telephones']['telephone']['number']
        catch e
            return ""


planner.page = {
    setup_shortcuts: ->
      shortcut_options = {
        'type':'keydown'
        'propagate':true
        'target':document
      }
      shortcut.add("Ctrl+M",->
        $('#full_map').hide()
      ,shortcut_options)

      shortcut.add("Ctrl+I",->
        planner.main_controller.step_through_itinerary()
      ,shortcut_options)


    clear_main_list : ->
        $('#main_list_info').empty()

    show_main_list : ->
        $('#main_list_info').show()

    hide_main_list : ->
        $('#main_list_info').hide()

    update_results_info : ->
        info_text = planner.type_labels[planner.selected_list.thing_type] +
                " - near " + (planner.itinerary.last_name() || "me")
        $('#info_text').text(info_text)

    block_all_non_chrome_browsers : ->
        if !(navigator.userAgent.toLowerCase().indexOf('chrome') > -1)
            alert("Sorry this site currently only supports Chrome")
            document.location = "http://www.lonelyplanet.com"

    set_map:  (latitude, longitude, thing_name) ->
        if planner.itinerary.last_name()
          last_item = planner.itinerary.last()
          previous_latitude = last_item.get('latitude')
          previous_longitude = last_item.get('longitude')
          previous_name = last_item.get('name')
        else
          previous_latitude = planner.user.latitude
          previous_longitude = planner.user.longitude
          previous_name = "Starting Location"

        latlng = new google.maps.LatLng(latitude, longitude)
        previous_latlng = new google.maps.LatLng(previous_latitude, previous_longitude)
        distance = distance_between_points(latitude, longitude, previous_latitude, previous_longitude)

        myOptions = {
          zoom: zoom_level(distance),
          center: previous_latlng,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        }
        map = new google.maps.Map(document.getElementById("map"), myOptions)
        marker = new google.maps.Marker
          position: latlng,
          title: thing_name
        marker.setMap(map)
        marker = new google.maps.Marker
          position: previous_latlng,
          title: previous_name,
          icon: 'images/regroup_pin.png'
        marker.setMap(map)

    render_place_select_map: ->
        place = planner.user.place
        center_latitude = (parseFloat(place.get('north-latitude')) + parseFloat(place.get('south-latitude'))) / 2
        center_longitude = (parseFloat(place.get('east-longitude')) + parseFloat(place.get('west-longitude'))) / 2
        latlng = new google.maps.LatLng(center_latitude, center_longitude)
        myOptions = {
          zoom: 10,
          center: latlng,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        }
        $('#main_list_info').append('<li><a href="#get_day">Use this as my starting location</a></li>')
        $('#main_list_info').append('<li><div id="place_map"></div></li>')
        place_map = new google.maps.Map(document.getElementById("place_map"), myOptions)

        $('#drop_pin').click ->
            alert marker.getPosition()
            return false


        planner.user.marker = new google.maps.Marker
          position: latlng
          title: 'Starting point'
          animation: google.maps.Animation.DROP
          draggable: true
        planner.user.marker.setMap(place_map)
}


zoom_level = (meters) ->
    return 15 if meters<700
    return 14 if meters<1500
    return 13 if meters<2000
    return 12 if meters<6000
    return 11 if meters<10000
    return 10

distance_between_points = (lat1, lon1, lat2, lon2) ->
# http://stackoverflow.com/questions/27928/how-do-i-calculate-distance-between-two-latitude-longitude-points
    R = 6371 # Radius of the earth in km

    # Converts numeric degrees to radians
    # http://stackoverflow.com/questions/5260423/torad-javascript-function-throwing-error
    if (typeof(Number.prototype.toRad) == "undefined")
        Number.prototype.toRad = ->
            return this * Math.PI / 180

    dLat = (lat2-lat1).toRad()
    dLon = (lon2-lon1).toRad()
    a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(parseFloat(lat1).toRad()) * Math.cos(parseFloat(lat2).toRad()) *
                    Math.sin(dLon/2) * Math.sin(dLon/2)
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    d = R * c * 1000 # Distance in m
    return parseInt(d, 10)

_.templateSettings =
    interpolate : /\{\{(.+?)\}\}/g
