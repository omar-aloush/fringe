# Live Ground Station — flashing guide

One-time setup, about 10 minutes with a USB cable.

1. **Install the Arduino IDE** (2.x) from arduino.cc — free.
2. **Add ESP32 boards:** Tools ▸ Board ▸ Boards Manager… search `esp32`,
   install **esp32 by Espressif Systems**.
3. **Add the sensor library:** Library Manager (books icon) search
   `MPU6050_light`, install (author: Rafael Fetick).
4. **Open** `GroundStationSketch/GroundStationSketch.ino`.
5. **Edit the two lines at the top** — your WiFi name and password.
   Use a **2.4 GHz** network; the ESP32 cannot join 5 GHz networks.
6. **Select the board:** Tools ▸ Board ▸ esp32 ▸ **ESP32 Dev Module**.
7. **Plug in the board**, pick its port under Tools ▸ Port, click **Upload**.
   If the log stalls at "Connecting...", hold the **BOOT** button on the board.
8. **Open Serial Monitor** at 115200 baud. After ~10 seconds you'll see:

   ```
   Fringe Live Ground Station online
     http://192.168.1.42
     http://fringe-station.local
   ```

9. **In Fringe:** open any event, scroll to the Live Ground Station card, tap
   connect. Auto-find uses `fringe-station.local`; if your router blocks `.local`
   name lookup, type the IP from step 8 instead.

## Verify without the app

Open the printed address in any browser — you should see live JSON, and
`tilt_x` / `tilt_y` should change as you tilt the board.

## For judges

The full measurement pipeline ships in this repository: the sketch
(`Hardware/`), the wiring guide, and this flashing guide. In the app, live
readings are labeled **LIVE SENSOR** and modeled products stay marked
**MODELED** — the two are never mixed.
