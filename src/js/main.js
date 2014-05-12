(function() {
  var account, acquireGeoLocation, addLiveEvent, addMapMarker, bindDomElements, closeLocation, enableLiveForm, errorAquireLocation, eventListeners, geolocation, infoWindows, initializeLocation, initialized, isTouchDevice, loadMap, map, mapTypes, markers, myInfoWindow, myInfoWindowTemplate, newSession, openLocation, pingInterval, profile, setDelay, setGeoLocation, toggleMyInfoWindow, uid, updateLocation, updateMyInfoWindow, urlParts;

  infoWindows = [];

  markers = [];

  eventListeners = [];

  geolocation = {};

  mapTypes = {};

  map = null;

  uid = null;

  account = null;

  profile = null;

  pingInterval = null;

  newSession = false;

  myInfoWindow = null;

  initialized = false;

  urlParts = window.location.pathname.split("!");

  if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)) {
    isTouchDevice = true;
  }

  myInfoWindowTemplate = '<div class="balloon"><span id="location-id"><%- url %></span><input type="text" id="location-name" placeholder="Name"  maxlength="36" value="<%- name %>" /><br/><textarea id="location-description" placeholder="Description (optional)"  maxlength="100"><%- description %></textarea><br/><span class="update-location-status">One moment..</span><button class="share-trigger" onclick="findmehere.openLocation()">Share location</button><button class="unshare-trigger" onclick="findmehere.closeLocation()">Unshare location</button></div>';

  if (!navigator.geolocation) {
    document.body.className = "unsupported";
  }

  if (isTouchDevice) {
    document.getElementById("findmehere-app").className = "is-touch-device";
  }

  acquireGeoLocation = function() {
    return navigator.geolocation.getCurrentPosition(setGeoLocation, errorAquireLocation);
  };

  setGeoLocation = function(navigatorGeoLocation) {
    geolocation = navigatorGeoLocation;
    if (!initialized) {
      initializeLocation();
      return initialized = true;
    }
  };

  initializeLocation = function() {
    var auth, firebase;
    document.body.className = "initialized";
    firebase = new Firebase("https://findmehere.firebaseIO.com/");
    auth = new FirebaseSimpleLogin(firebase, function(error, user) {
      var users;
      if (error) {
        console.log(error);
      } else if (user) {
        account = firebase.child("users/" + user.uid + "/data");
        users = firebase.child("users/");
        uid = user.uid;
        account.once("value", function(data) {
          data = data.val();
          profile = data || {};
          profile.uid = user.uid;
          if (data && data.name) {
            if (data.active) {
              addMapMarker(data.name, data, map);
              document.body.className = "location-shared";
            }
            enableLiveForm();
          }
          return toggleMyInfoWindow();
        });
        account.onDisconnect().update({
          active: false
        });
        users.on("child_added", function(snapshot) {
          var id, location, value;
          value = snapshot.val();
          location = value.data;
          id = snapshot.name();
          if (location.active && location.position) {
            return addMapMarker(id, location, map);
          }
        });
        users.on("child_changed", function(snapshot) {
          var id, location, value;
          value = snapshot.val();
          location = value.data;
          id = snapshot.name();
          if (location.active && location.position) {
            return addMapMarker(id, location, map);
          } else {
            if (markers[id]) {
              markers[id].setMap(null);
              return delete markers[id];
            }
          }
        });
      } else {
        auth.login("anonymous", {
          rememberMe: true
        });
      }
    });
    bindDomElements();
    loadMap();
  };

  loadMap = function() {
    var blurMapOptions, blurMapType, focusMapOptions, focusMapType, mapOptions, position;
    mapOptions = {
      zoom: 5,
      mapTypeId: "findmehere_type"
    };
    map = new google.maps.Map(document.getElementById("map-canvas"), mapOptions);
    position = new google.maps.LatLng(geolocation.coords.latitude, geolocation.coords.longitude);
    blurMapOptions = [
      {
        stylers: [
          {
            saturation: -100
          }, {
            visibility: "simplified"
          }
        ]
      }
    ];
    focusMapOptions = [
      {
        stylers: [
          {
            saturation: 0
          }
        ]
      }
    ];
    map.setCenter(position);
    blurMapType = new google.maps.StyledMapType(blurMapOptions, null);
    focusMapType = new google.maps.StyledMapType(focusMapOptions, null);
    mapTypes["blur"] = blurMapType;
    mapTypes["focus"] = focusMapType;
    map.mapTypes.set("findmehere_type", focusMapType);
  };

  updateMyInfoWindow = function(data) {
    document.getElementById("location-name").value = data.name || "";
    return document.getElementById("location-description").value = data.description || "";
  };

  toggleMyInfoWindow = function() {
    var index, position, tData;
    position = new google.maps.LatLng(geolocation.coords.latitude, geolocation.coords.longitude);
    if (!myInfoWindow) {
      tData = {};
      tData.name = profile.name || "";
      tData.description = profile.description || "";
      tData.url = document.domain + "/!" + profile.uid.split("anonymous:-")[1];
      myInfoWindow = new google.maps.InfoWindow({
        map: map,
        position: position,
        content: _.template(myInfoWindowTemplate, tData),
        pixelOffset: new google.maps.Size(0, -30)
      });
      myInfoWindow.opened = true;
      google.maps.event.addListener(myInfoWindow, "closeclick", function() {
        return myInfoWindow.opened = false;
      });
    } else {
      if (!myInfoWindow.opened) {
        for (index in infoWindows) {
          infoWindows[index].close();
        }
        map.setCenter(position);
        myInfoWindow.open(map);
        myInfoWindow.opened = true;
        updateMyInfoWindow(profile);
      } else {
        myInfoWindow.close();
        myInfoWindow.opened = false;
      }
    }
  };

  addMapMarker = function(id, location, map) {
    var content, currentContent, eventListener, iconSrc, infoWindow, marker, newContent;
    if (!location.position) {
      return;
    }
    if (!markers[id]) {
      iconSrc = uid === id ? "graphics/pointer-sister-me.png" : "graphics/pointer-sister.png";
      marker = new google.maps.Marker({
        position: new google.maps.LatLng(location.position[0], location.position[1]),
        map: map,
        animation: google.maps.Animation.DROP,
        icon: iconSrc
      });
      markers[id] = marker;
      content = "<div class=\"someone\"><h1>" + location.name + "</h1>";
      if (location.description) {
        content += "<p>" + location.description + "</p>";
      } else {
        content += "</div>";
      }
      infoWindow = new google.maps.InfoWindow({
        content: content,
        pixelOffset: new google.maps.Size(-1, 0)
      });
      infoWindows[id] = infoWindow;
    } else {
      marker = markers[id];
      google.maps.event.removeListener(eventListeners[id]);
      infoWindow = infoWindows[id];
      currentContent = infoWindow.getContent();
      newContent = "<div class=\"someone\"><h1>" + location.name + "</h1>";
      if (location.description) {
        newContent += "<p>" + location.description + "</p></div>";
      } else {
        newContent += "</div>";
      }
      infoWindow.setContent(newContent);
    }
    eventListener = google.maps.event.addListener(marker, "click", function() {
      var index;
      for (index in infoWindows) {
        infoWindows[index].close();
      }
      if (uid === id) {
        return toggleMyInfoWindow();
      } else {
        myInfoWindow.opened = true;
        toggleMyInfoWindow();
        return infoWindow.open(map, marker);
      }
    });
    eventListeners[id] = eventListener;
    if (urlParts[1]) {
      if (id === "anonymous:-" + urlParts[1]) {
        myInfoWindow.opened = true;
        toggleMyInfoWindow();
        return infoWindow.open(map, marker);
      }
    }
  };

  openLocation = function() {
    var description, name;
    name = document.getElementById("location-name").value;
    description = document.getElementById("location-description").value;
    if (!name) {
      return;
    }
    console.log("[Opening location..]");
    document.body.className = "update-location";
    account.set({
      name: name,
      description: description,
      position: [geolocation.coords.latitude, geolocation.coords.longitude],
      active: true
    });
    document.body.className = "location-shared";
    enableLiveForm();
  };

  closeLocation = function() {
    document.body.className = "update-location";
    account.update({
      active: false
    });
    document.body.className = "location-unshared";
  };

  updateLocation = function() {
    var description, name, update;
    console.log("[Updating location..]");
    name = document.getElementById("location-name").value;
    description = document.getElementById("location-description").value;
    acquireGeoLocation();
    update = {};
    if (name) {
      update["name"] = name;
    }
    if (description) {
      update["description"] = description;
    }
    update["position"] = [geolocation.coords.latitude, geolocation.coords.longitude];
    account.update(update);
    profile = update;
  };

  bindDomElements = function() {
    return addLiveEvent("click", "my-location-window", function(e) {
      return toggleMyInfoWindow();
    });
  };

  enableLiveForm = function() {
    var triggerUpdate;
    console.log("[Enable live form..]");
    addLiveEvent("keyup", "location-name", function(e) {
      if (this.value && e.keyCode !== 37 && e.keyCode !== 38 && e.keyCode !== 39 && e.keyCode !== 40) {
        return triggerUpdate();
      }
    });
    addLiveEvent("keyup", "location-description", function(e) {
      if (this.value && e.keyCode !== 37 && e.keyCode !== 38 && e.keyCode !== 39 && e.keyCode !== 40) {
        return triggerUpdate();
      }
    });
    triggerUpdate = function() {
      console.log("[Trigger update..]");
      return setDelay((function() {
        return updateLocation();
      }), 500);
    };
  };

  errorAquireLocation = function(error) {
    return document.body.className = "permission-denied";
  };

  addLiveEvent = function(eventType, elementId, cb) {
    return document.addEventListener(eventType, function(event) {
      if (event.target.id === elementId) {
        return cb.call(event.target, event);
      }
    });
  };

  Element.prototype.remove = function() {
    this.parentElement.removeChild(this);
  };

  setDelay = (function() {
    var timer;
    timer = 0;
    return function(callback, ms) {
      clearTimeout(timer);
      return timer = setTimeout(callback, ms);
    };
  })();

  window.onload = function() {
    return acquireGeoLocation();
  };

  window.findmehere = {};

  window.findmehere.openLocation = openLocation;

  window.findmehere.closeLocation = closeLocation;

}).call(this);
