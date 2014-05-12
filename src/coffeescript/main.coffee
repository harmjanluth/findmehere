# Setup global geolocation
#
infoWindows			= []
markers				= []
eventListeners		= []

geolocation 		= {}
mapTypes			= {}

map 				= null
uid					= null
account				= null
profile				= null
pingInterval    	= null
newSession 			= false
myInfoWindow    	= null
initialized 		= false

urlParts			= window.location.pathname.split( "!" )
isTouchDevice 		= true if /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test( navigator.userAgent ) 

myInfoWindowTemplate = '<div class="balloon"><span id="location-id"><%- url %></span><input type="text" id="location-name" placeholder="Name"  maxlength="36" value="<%- name %>" /><br/><textarea id="location-description" placeholder="Description (optional)"  maxlength="100"><%- description %></textarea><br/><span class="update-location-status">One moment..</span><button class="share-trigger" onclick="findmehere.openLocation()">Share location</button><button class="unshare-trigger" onclick="findmehere.closeLocation()">Unshare location</button></div>'

# If browser doesn't support geolocation, leave
#
if not navigator.geolocation
	document.body.className = "unsupported"

if isTouchDevice
	document.getElementById( "findmehere-app" ).className = "is-touch-device"

# Native browser geolocation
#
acquireGeoLocation = ->
	navigator.geolocation.getCurrentPosition setGeoLocation, errorAquireLocation

# Set global geolocation object
#        
setGeoLocation = ( navigatorGeoLocation ) ->
	geolocation = navigatorGeoLocation

	if not initialized
		initializeLocation()
		initialized = true

# Initialize user location
#
initializeLocation = ->

	document.body.className = "initialized"

	# Setup firebase
	#
	firebase 	= new Firebase "https://findmehere.firebaseIO.com/"
	auth 		= new FirebaseSimpleLogin( firebase, (error, user) ->
		
		if error
			
			# An error occurred while attempting login
			#
			console.log error
		
		else if user

			# User authenticated with Firebase
			#
			account 				= firebase.child( "users/" + user.uid + "/data" )
			users					= firebase.child( "users/" )

			# Update global
			#
			uid = user.uid

			# Fill form
			#
			account.once "value", ( data ) ->

				data = data.val()

				# Globalize
				#
				profile = data || {}
				profile.uid = user.uid

				if data && data.name

					if data.active

						addMapMarker( data.name, data, map )

						# Set proper styling
						#
						document.body.className = "location-shared"

					# Enable live editing
					#
					enableLiveForm()

				toggleMyInfoWindow()

			# Don't show when disconnected
			#
			account.onDisconnect().update( active : false )

			# User added
			#
			users.on( "child_added", ( snapshot ) ->
				
				value 		= snapshot.val()
				location 	= value.data
				id 			= snapshot.name()

				if location.active && location.position
					addMapMarker( id, location, map )
			)

			# User changed
			#
			users.on( "child_changed", ( snapshot ) ->
				
				value 		= snapshot.val()
				location 	= value.data
				id 			= snapshot.name() 

				# Only add if active location
				#
				if location.active && location.position
					addMapMarker( id, location, map )

				else
					
					# Check if its there already
					#
					if markers[ id ]
						markers[ id ].setMap null
						delete markers[ id ]				
			)

		else

			# Setup new sessions
			#
			auth.login "anonymous",
				rememberMe: true
		
		return
	)

	# Make elements interactive
	#
	bindDomElements()

	# Always load the map
	#
	loadMap()
	
	return

# Load the Google map
#
loadMap = ->

	mapOptions              =
		zoom                : 5
		mapTypeId           : "findmehere_type"

	map                     = new google.maps.Map( document.getElementById( "map-canvas" ), mapOptions )
	position                = new google.maps.LatLng( geolocation.coords.latitude, geolocation.coords.longitude )

	blurMapOptions 			= [
		stylers: [
			{
				saturation: -100
			},
			{
				visibility: "simplified"
			}
			]
		]

	focusMapOptions 		= [
		stylers: [
			{
				saturation: 0
			}
			]
		]

	map.setCenter( position )
	
	blurMapType = new google.maps.StyledMapType( blurMapOptions, null )
	focusMapType = new google.maps.StyledMapType( focusMapOptions, null )

	mapTypes[ "blur" ] = blurMapType
	mapTypes[ "focus" ] = focusMapType

	map.mapTypes.set "findmehere_type", focusMapType

	return

updateMyInfoWindow = ( data ) ->

	document.getElementById( "location-name" ).value 			= data.name || ""
	document.getElementById( "location-description" ).value 	= data.description || ""

toggleMyInfoWindow = () ->

	position                	= new google.maps.LatLng( geolocation.coords.latitude, geolocation.coords.longitude )

	if not myInfoWindow

		# console.log profile

		tData					= {}
		tData.name 				= profile.name || ""
		tData.description 		= profile.description || ""
		tData.url 				= document.domain + "/!" + profile.uid.split( "anonymous:-" )[ 1 ]

		myInfoWindow            = new google.maps.InfoWindow
			map                 : map
			position            : position
			content             : _.template( myInfoWindowTemplate, tData )
			pixelOffset			: new google.maps.Size( 0, -30 )

		# Set status
		#
		myInfoWindow.opened = true

		# Sync toggle with close btn
		#
		google.maps.event.addListener myInfoWindow, "closeclick", ->
			# map.mapTypes.set "findmehere_type", mapTypes[ "focus" ]
			myInfoWindow.opened = false

	else

		# Toggle infoWindow
		#
		if not myInfoWindow.opened

			# Close other windows
			#
			for index of infoWindows
			
				infoWindows[ index ].close()

			# Open and set state
			#
			# map.mapTypes.set "findmehere_type", mapTypes[ "blur" ]
			map.setCenter position
			myInfoWindow.open map
			myInfoWindow.opened = true

			updateMyInfoWindow( profile )

		else

			# Close and set state
			#
			# map.mapTypes.set "findmehere_type", mapTypes[ "focus" ]
			myInfoWindow.close()
			myInfoWindow.opened = false

	return

addMapMarker = ( id, location, map ) ->

	return if not location.position

	# Check if marker already exists
	#
	if not markers[ id ]

		iconSrc				= if uid is id then "graphics/pointer-sister-me.png" else "graphics/pointer-sister.png" 
		
		marker 				= new google.maps.Marker
			position        : new google.maps.LatLng location.position[ 0 ], location.position[ 1 ]
			map             : map
			animation 		: google.maps.Animation.DROP
			icon			: iconSrc
			
		# Add this new marker to collection
		#
		markers[ id ] = marker

		# Setup marker content
		#
		content = "<div class=\"someone\"><h1>" + location.name + "</h1>"

		# Add description if any
		#
		if( location.description )
			content += "<p>" + location.description + "</p>"
		else
			content += "</div>"

		# Always update infowindow
		#
		infoWindow          = new google.maps.InfoWindow 
								content: content
								pixelOffset: new google.maps.Size( -1, 0 )

		# Collect all info windows
		#
		infoWindows[ id ] = infoWindow

	else

		# Reference to existing marker
		#
		marker = markers[ id ]

		# Remove existing listener
		#
		google.maps.event.removeListener( eventListeners[ id ] );
	
		# Reference to existing infoWindow
		#
		infoWindow = infoWindows[ id ]

		# Update window
		#
		currentContent = infoWindow.getContent()

		# Setup marker content
		#
		newContent = "<div class=\"someone\"><h1>" + location.name + "</h1>"

		# Add description if any
		#
		if( location.description )
			newContent += "<p>" + location.description + "</p></div>"
		else
			newContent += "</div>"

		# Update content if there is other
		#
		#if newContent isnt currentContent
		infoWindow.setContent newContent

	# Setup new click listener
	#
	eventListener = google.maps.event.addListener marker, "click", ->

		for index of infoWindows
			
			infoWindows[ index ].close()
		
		if uid is id
			toggleMyInfoWindow()
		else
			myInfoWindow.opened = true
			toggleMyInfoWindow()
			infoWindow.open map, marker

	# Add to new listener to array Listeners
	#
	eventListeners[ id ] = eventListener

	# Check if we need to open this one
	#
	if urlParts[ 1 ]

		if id is "anonymous:-" + urlParts[ 1 ]

			myInfoWindow.opened = true
			toggleMyInfoWindow()
			infoWindow.open map, marker
			
openLocation = ->

	name 		= document.getElementById( "location-name" ).value
	description = document.getElementById( "location-description" ).value

	if not name

		return

	# Open the location?
	#
	console.log "[Opening location..]"

	document.body.className = "update-location"

	# Update location
	#
	account.set( 
		name 		: name
		description : description
		position 	: [ geolocation.coords.latitude, geolocation.coords.longitude ]
		active		: true
	)

	# Set proper styling
	#
	document.body.className = "location-shared"

	# Enable live editing
	#
	enableLiveForm()

	return

closeLocation = ->

	document.body.className = "update-location";

	# Update location
	#
	account.update( 
		active		: false
	)

	# Set proper styling
	#
	document.body.className = "location-unshared"

	return


updateLocation = ->

	console.log "[Updating location..]"

	# document.body.className = "update-location"

	name 		= document.getElementById( "location-name" ).value
	description = document.getElementById( "location-description" ).value

	# Update geolocation
	#
	acquireGeoLocation()

	update 		= {}

	if name
		update[ "name" ] = name

	if description
		update[ "description" ] = description

	# Add geolocation
	#
	update[ "position" ] = [ geolocation.coords.latitude, geolocation.coords.longitude ]

	# Update location
	#
	account.update( update )

	# Update global
	#
	profile = update

	# Reset styling
	#
	# document.body.className = "location-shared"

	return

bindDomElements = ->

	addLiveEvent "click", "my-location-window", ( e ) ->
		
		toggleMyInfoWindow()

# Enable editing form on keyup
#
enableLiveForm = ->

	console.log "[Enable live form..]"

	addLiveEvent "keyup", "location-name", ( e ) ->
		if @value and e.keyCode isnt 37 and e.keyCode isnt 38 and e.keyCode isnt 39 and e.keyCode isnt 40
			triggerUpdate()

	addLiveEvent "keyup", "location-description", ( e ) ->
		if @value and e.keyCode isnt 37 and e.keyCode isnt 38 and e.keyCode isnt 39 and e.keyCode isnt 40
			triggerUpdate()

	triggerUpdate = ->

		console.log "[Trigger update..]"

		setDelay (->
			
			updateLocation()			
		
		), 500

	return

# Could not get geolocation from browser
#
errorAquireLocation = ( error ) ->

	document.body.className = "permission-denied"

# Add live events to dom elements
#
addLiveEvent = (eventType, elementId, cb) ->
	document.addEventListener eventType, (event) ->
		cb.call event.target, event  if event.target.id is elementId


# Remove DOM elements
#
Element::remove = ->
	@parentElement.removeChild this
	return

# Delaying methods
#
setDelay = (->
	
	timer = 0

	(callback, ms) ->
		clearTimeout timer
		timer = setTimeout(callback, ms)
)()

window.onload = ->
	acquireGeoLocation()

# Expose functions
#
window.findmehere 					= {}
window.findmehere.openLocation 		= openLocation
window.findmehere.closeLocation 	= closeLocation