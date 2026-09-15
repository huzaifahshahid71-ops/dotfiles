pragma Singleton

// Weather for the dashboard, modelled on Nisfere's WeatherService: the
// Open-Meteo forecast, in °C and mph.
//
// Location: ~/.local/share/desktop-profiles/sayconlun/support/state/config/location.json when it exists -
//   {"name": "Leeds", "lat": 53.80, "lon": -1.55}
// otherwise an IP lookup (ip-api.com), which only knows roughly where the
// connection comes out. Refreshes hourly; retries every 30 s until the first
// success.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string city: ""
    property real lat: NaN
    property real lon: NaN
    property bool ready: false
    property bool loading: false
    property string error: ""
    property date updated: new Date(0)

    property real temperature: 0
    property real feelsLike: 0
    property int humidity: 0
    property real wind: 0
    property int code: 0
    property bool isDay: true
    property var daily: []                  // [{date, code, min, max}]

    readonly property var descriptions: ({
        0: "Clear", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
        45: "Fog", 48: "Fog", 51: "Drizzle", 53: "Drizzle", 55: "Drizzle",
        56: "Freezing drizzle", 57: "Freezing drizzle", 61: "Light rain", 63: "Rain",
        65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain", 71: "Light snow",
        73: "Snow", 75: "Heavy snow", 77: "Snow grains", 80: "Rain showers",
        81: "Heavy rain showers", 82: "Violent rain showers", 85: "Snow showers",
        86: "Heavy snow showers", 95: "Thunderstorm", 96: "Thunderstorm with hail",
        99: "Thunderstorm with hail"
    })

    function describe(c) {
        return descriptions[c] || "Unknown"
    }

    function icon(c, day) {
        if (day === false && c <= 1) return "moon"
        if (day === false && c === 2) return "cloud-moon"
        if (c <= 1) return "sun"
        if (c === 2) return "cloud-sun"
        if (c === 45 || c === 48) return "cloud-fog"
        if (c >= 51 && c <= 57) return "cloud-drizzle"
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "cloud-rain"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "cloud-snow"
        if (c >= 95) return "cloud-lightning"
        return "cloud"
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/share/desktop-profiles/sayconlun/support/state/config/location.json"
        printErrors: false
        onLoaded: {
            try {
                const l = JSON.parse(text())
                if (isFinite(l.lat) && isFinite(l.lon)) {
                    root.city = l.name || ""
                    root.lat = l.lat
                    root.lon = l.lon
                }
            } catch (e) {
                console.warn("WeatherService: unreadable location.json:", e)
            }
            root.update()
        }
        onLoadFailed: root.update()
    }

    function request(url, callback) {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.timeout = 10000
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                callback(xhr.status, xhr.responseText)
        }
        xhr.ontimeout = () => callback(0, "")
        xhr.send()
    }

    function update() {
        if (loading)
            return
        loading = true
        if (isFinite(lat) && isFinite(lon)) {
            fetchForecast()
            return
        }
        request("http://ip-api.com/json/?fields=status,city,lat,lon", (status, body) => {
            try {
                const d = JSON.parse(body)
                if (d.status === "success") {
                    root.city = d.city
                    root.lat = d.lat
                    root.lon = d.lon
                    root.fetchForecast()
                    return
                }
            } catch (e) {}
            root.fail("Could not work out your location")
        })
    }

    function fetchForecast() {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&timezone=auto&forecast_days=7&wind_speed_unit=mph"
        request(url, (status, body) => {
            try {
                const d = JSON.parse(body)
                const c = d.current
                root.temperature = c.temperature_2m
                root.feelsLike = c.apparent_temperature
                root.humidity = c.relative_humidity_2m
                root.wind = c.wind_speed_10m
                root.code = c.weather_code
                root.isDay = c.is_day === 1
                root.daily = d.daily.time.map((t, i) => ({
                    date: t,
                    code: d.daily.weather_code[i],
                    min: d.daily.temperature_2m_min[i],
                    max: d.daily.temperature_2m_max[i]
                }))
                root.ready = true
                root.error = ""
                root.updated = new Date()
                root.loading = false
            } catch (e) {
                root.fail("Weather is unavailable right now")
            }
        })
    }

    function fail(message) {
        error = message
        loading = false
        if (!ready)
            retry.restart()
    }

    Timer {
        id: retry
        interval: 30000
        onTriggered: root.update()
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root.update()
    }
}
