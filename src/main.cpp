#include <Arduino.h>
#include <Wire.h>
#include <INA226.h>

// INA226 I2C address
constexpr uint8_t INA_ADDRESS = 0x40;

// ESP32-C3 SuperMini pins on the new PCB
constexpr uint8_t ALERT_PIN = 5;
constexpr uint8_t SCL_PIN   = 6;
constexpr uint8_t SDA_PIN   = 7;

// INA226 version of the board uses a 3.5 milliohm shunt.
// The schematic describes this as two R007 resistors in parallel.
constexpr float SHUNT_OHMS = 0.004f;

// Calibrated against a reference load: 1.10 A indicated, 0.95 A actual.
// Apply the same correction to current and the derived power reading.
constexpr float CURRENT_CALIBRATION = 0.95f / 1.10f;

// Suppress the INA226's small zero-current offset and ADC-count noise.
constexpr float CURRENT_ZERO_DEADBAND_AMPS = 0.003f;

// 23 A places the INA226 near its maximum shunt-voltage range:
// 23 A × 0.0035 ohm = 0.0805 V
constexpr float MAX_CURRENT_AMPS = 23.0f;

INA226 INA(INA_ADDRESS);

void setup()
{
    Serial.begin(115200);
    delay(2000);

    // INA226 ALERT output is normally open-drain.
    pinMode(ALERT_PIN, INPUT_PULLUP);

    // New PCB I2C pins
    Wire.begin(SDA_PIN, SCL_PIN);
    Wire.setClock(400000);

    if (!INA.begin())
    {
        while (true)
        {
            Serial.println("0,0,0,0");
            delay(1000);
        }
    }

    // Average 16 measurements to reduce noise.
    INA.setAverage(INA226_16_SAMPLES);

    // Configure library calibration for the new shunt.
    INA.setMaxCurrentShunt(MAX_CURRENT_AMPS, SHUNT_OHMS);
}

void loop()
{
    const float voltage = INA.getBusVoltage();
    const float shunt_mV = INA.getShuntVoltage_mV();

    // Convert millivolts to volts, then divide by shunt resistance.
    const float uncalibrated_current_A =
        (shunt_mV / 1000.0f) / SHUNT_OHMS;
    float current_A = uncalibrated_current_A * CURRENT_CALIBRATION;
    if (fabsf(current_A) < CURRENT_ZERO_DEADBAND_AMPS)
    {
        current_A = 0.0f;
    }

    const float power_W = voltage * current_A;

    // Preserve the existing Python application data format:
    // Voltage, Current, Power, Shunt millivolts
    Serial.print(voltage, 3);
    Serial.print(",");
    Serial.print(current_A, 3);
    Serial.print(",");
    Serial.print(power_W, 3);
    Serial.print(",");
    Serial.println(shunt_mV, 4);

    delay(250);
}
