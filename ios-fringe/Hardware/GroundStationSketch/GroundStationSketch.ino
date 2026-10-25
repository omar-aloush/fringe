/*
  Fringe - Live Ground Station
  ============================
  Streams real motion readings from your desk into the Fringe app over WiFi.

  Hardware: ESP32 dev board + GY-521 (MPU-6050) breakout, 4 jumper wires.
  Wiring:   see WIRING.md next to this sketch.
  Flashing: see FLASHING.md next to this sketch.

  Edit the two lines below, upload, and the station answers at:
      http://fringe-station.local/     (or the IP printed to Serial Monitor)

  The app polls "/" for JSON like:
    {"station":"fringe-ground-station","fw":1,"uptime_s":123,"sensor":true,
     "tilt_x":-0.42,"tilt_y":1.87,"temp_c":24.31}
  "sensor":false means heartbeat mode - station online, no sensor attached.
*/

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <Wire.h>
#include <MPU6050_light.h>

// ---- EDIT THESE TWO LINES ----------------------------------------------
const char* WIFI_SSID     = "YOUR_WIFI_NAME";      // must be a 2.4 GHz network
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
// ------------------------------------------------------------------------

const char* HOSTNAME   = "fringe-station";         // becomes fringe-station.local
const char* STATION_ID = "fringe-ground-station";
const int   FIRMWARE_VERSION = 1;

WebServer server(80);
MPU6050 mpu(Wire);

bool sensorAttached = false;
unsigned long bootMs;

String statusJson() {
  String out = "{\"station\":\"" STATION_ID "\",\"fw\":";
  out += FIRMWARE_VERSION;
  out += ",\"uptime_s\":" + String((millis() - bootMs) / 1000UL);
  if (sensorAttached) {
    mpu.update();
    out += ",\"sensor\":true";
    out += ",\"tilt_x\":" + String(mpu.getAngleX(), 2);
    out += ",\"tilt_y\":" + String(mpu.getAngleY(), 2);
    out += ",\"temp_c\":" + String(mpu.getTemp(), 2);
  } else {
    out += ",\"sensor\":false,\"tilt_x\":null,\"tilt_y\":null,\"temp_c\":null";
  }
  out += "}";
  return out;
}

void handleStatus() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", statusJson());
}

void setup() {
  Serial.begin(115200);
  bootMs = millis();

  Wire.begin();  // SDA = GPIO21, SCL = GPIO22 on standard ESP32 dev boards
  if (mpu.begin() == 0) {
    sensorAttached = true;
    Serial.print(F("MPU-6050 found. Calibrating gyro - keep the board still"));
    mpu.calcGyroOffsets(true);  // prints progress dots, takes ~3 seconds
    Serial.println(F(" done."));
  } else {
    Serial.println(F("No MPU-6050 detected - heartbeat mode (station online, no motion data)."));
  }

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print(F("Connecting to WiFi"));
  while (WiFi.status() != WL_CONNECTED) {
    delay(400);
    Serial.print('.');
  }
  Serial.println();

  if (MDNS.begin(HOSTNAME)) {
    MDNS.addService("http", "tcp", 80);
  }

  server.on("/", HTTP_GET, handleStatus);
  server.on("/health", HTTP_GET, []() { server.send(200, "text/plain", "ok"); });
  server.begin();

  Serial.println(F("Fringe Live Ground Station online"));
  Serial.print(F("  http://"));
  Serial.println(WiFi.localIP());
  Serial.print(F("  http://"));
  Serial.print(HOSTNAME);
  Serial.println(F(".local"));
}

void loop() {
  server.handleClient();
  if (sensorAttached) mpu.update();  // keeps the tilt filter fresh at loop rate
  delay(2);
}
