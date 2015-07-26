<?php

$power_to_heat_ratio = 0.01;
$cooling_ratio = 0.001;

$power = 0;
$temperature = 0;
$time = 0;

$soak_temperature = .65;

$soak_start = $soak_time = 0;

define( INITIAL_STAGE, 1 );
define( SOAK_STAGE, 2 );
define( END_STAGE, 4 );

$stage = INITIAL_STAGE;

while ( true ) {
  if ( $stage == INITIAL_STAGE || $stage == END_STAGE ) {
    if ( $temperature >= $soak_temperature && $stage == INITIAL_STAGE ) {
      $soak_start = $time;
      $stage = SOAK_STAGE;
    }

    if ( $stage == INITIAL_STAGE ) {
      $target_temp = ($time / 90) * $soak_temperature;
      $power = 15 * ($target_temp - $temperature);
    } else {
      $power = 1;
    }
  } elseif ( $stage == SOAK_STAGE ) {
    $soak_time = $time - $soak_start;
    if ( $soak_time >= 45 ) $stage = END_STAGE;

    $target_temp = $soak_temperature + (($soak_time / 45) * 0.1);
    $power = 15 * ( $target_temp - $temperature );
  }

  // Apply heat :)
  $temperature += $power * $power_to_heat_ratio;
  $temperature -= $cooling_ratio;

  if ( $temperature > 1 ) break;

  //print $time . " " . round( $temperature, 2 ) . " - " . $power . PHP_EOL;
  print $time . " " . round( $temperature, 2 ) . PHP_EOL;
  $time++;
}
