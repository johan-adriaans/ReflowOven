#define STAGE_INITIAL 1  // Heat up to 0.75
#define STAGE_SOAK 2     // Soak at 0.75 for 45 seconds
#define STAGE_END 3      // Heat up to 1
#define STAGE_FINISHED 4 // Shut down heat and play buzzer
#define STAGE_ERROR 5    // Shut down heat and play buzzer

#define MODE_NORMAL 1    // Normal operation
#define MODE_CALIBRATE 2 // Calibration mode, blink led and listen for pushbutton

// Heat profile
#define SOAK_TEMPERATURE 180   // At which temperature shall we start soaking?
#define TARGET_TEMPERATURE 250 // Target temperature..
#define MAX_HEAT_OFFSET 20     // Area around target heat used for calculating heater power
#define MAX_HEATER_RATE 200    // Max PWM rate for heaterPin

// Pinout
int pushbuttonPin = 2;
int heaterPin = 3;
int sensorPowerPin = 4;
int buzzerPin = 5;
int ledPin = 13;
int sensorInputPin = 0;

int seconds = 0;
int pushbuttonState = 0;
int soakTimeStart = 0;
int soakTime = 0;
float heaterPower = 0;
float temperature = 0;
float targetTemperature = 0;

// Start in normal mode
int mode = MODE_NORMAL;
int stage = STAGE_INITIAL;

void setup()
{
  pinMode( heaterPin, OUTPUT );
  pinMode( buzzerPin, OUTPUT );
  pinMode( ledPin, OUTPUT );
  pinMode( pushbuttonPin, INPUT_PULLUP ); // Pull-up inverts HIGH/LOW state

  // Setup sensor
  //ADMUX = 0xC0; // REFS = 3, use 1.1V bandgap as reference
  //analogReference(INTERNAL1V1);
  analogReference( 3 );
  analogRead( sensorInputPin );
  pinMode( sensorPowerPin, OUTPUT );
  digitalWrite( sensorPowerPin, 1);

  Serial.begin( 57600 );
  Serial.println( "\n[Reflow oven]" );
  Serial.println( "##### INITIAL STAGE #####" );
}

int readTemperature ()
{
  // 380 ≈ 25°C and 765 ≈ 200°C
  int adc = analogRead( sensorInputPin );

  //Serial.print(adc);
  //Serial.print(": ");
  static int avg = 0;
  if ( avg == 0 ) {
    avg = adc;
  }
  avg = (3 * avg + adc) / 4;

  // assumes linear relationship between adc and temp, this is not correct!
  return map( avg, 380, 765, 25, 200 );
}

void loop()
{
  // Error occured, needs reset
  if ( stage == STAGE_ERROR ) return;

  static int lastUpdate;
  seconds = millis() / 1000;

  // Read button
  pushbuttonState = digitalRead( pushbuttonPin );
  if ( pushbuttonState == LOW && seconds < 5 ) {
    Serial.println( "Starting calibration mode" );
    mode = MODE_CALIBRATE;
  } else if ( pushbuttonState == LOW && seconds > 30 && mode == MODE_CALIBRATE ) {
    Serial.println( "Calibrated" );
    // TODO: Write sensor measurement to EPROM and shut down
  }

  if ( stage == STAGE_INITIAL ) {
    if ( temperature >= SOAK_TEMPERATURE && stage == STAGE_INITIAL ) {
      Serial.println( "##### SOAK STAGE #####" );
      soakTimeStart = seconds;
      stage = STAGE_SOAK;
    }

    targetTemperature = (seconds / 90.0) * SOAK_TEMPERATURE;
    heaterPower = (targetTemperature - temperature) / MAX_HEAT_OFFSET;
  } else if ( stage == STAGE_SOAK ) {
    soakTime = seconds - soakTimeStart;
    if ( soakTime >= 45 ) {
      Serial.println( "##### END STAGE #####" );
      stage = STAGE_END;
    }

    targetTemperature = SOAK_TEMPERATURE + ((soakTime / 45.0) * 10);
    heaterPower = ( targetTemperature - temperature ) / MAX_HEAT_OFFSET;
  } else if ( stage == STAGE_END ) {
    heaterPower = 1;
  }

  if ( temperature >= TARGET_TEMPERATURE && stage < STAGE_FINISHED ) {
    Serial.println( "##### FINISHED #####" );
    heaterPower = 0;
    stage = STAGE_FINISHED;
  }

  if ( seconds != lastUpdate ) {
    if ( temperature > 300 ) {
      Serial.println( "Error: heat > 300 - Please attach sensor and reset" );
      stage = STAGE_ERROR;
      digitalWrite( ledPin, HIGH ); // Red alert! :)
      heaterPower = 0; // Turn heater off!
    }

    // Beep a few times
    static int beeps;
    if ( stage == STAGE_FINISHED && beeps < 6 ) {
      static bool beep;
      beep = !beep;
      digitalWrite( buzzerPin, beep ? HIGH : LOW );
      Serial.println( "Beep..." );
      beeps++;
    }

    // Apply heat
    int heaterLevel = min( 1, max( 0, heaterPower ) ) * MAX_HEATER_RATE;
    analogWrite( heaterPin, heaterLevel );
    if ( stage < STAGE_ERROR ) {
      digitalWrite( ledPin, heaterLevel > 1 ? HIGH : LOW );
    }

    // Read temperature
    temperature = readTemperature();

    Serial.print( seconds );
    Serial.print( " " );
    Serial.print( "temp:" );
    Serial.print( temperature );

    Serial.print( " " );

    Serial.print( "heater:" );
    Serial.println( heaterLevel );
    lastUpdate = seconds;
  }
}
