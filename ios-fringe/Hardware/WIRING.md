# Live Ground Station — wiring

Four wires, no soldering. The board is powered over USB (laptop or phone charger).

## Parts

- ESP32 dev board — any "ESP32 DevKit" style board (30 or 38 pins)
- GY-521 breakout (MPU-6050 accelerometer + gyro)
- 4 female–female jumper wires

## Connections

| GY-521 pin | ESP32 pin |
|------------|-----------|
| VCC        | 3V3       |
| GND        | GND       |
| SDA        | GPIO 21   |
| SCL        | GPIO 22   |

Notes:

- Power the sensor from **3V3**, never 5V/VIN.
- Keep the board flat and still for the first ~3 seconds after reset — the sketch
  calibrates the gyro then. Tilt angles are measured relative to that boot pose.
- No sensor attached? The station still runs in **heartbeat mode**: the app shows
  "station online, sensor pending" and the uptime, honestly labeled.

## Placement tip for the demo

Tape the sensor to the edge of a table and tap the tabletop — the live sparkline
in the app reacts instantly. For a quieter noise floor, put the board on a
notebook on a foam pad so keyboard thumps don't drown out the gentle stuff.
