#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <wiringPi.h>
#include <wiringPiI2C.h>

#define DRV8830_SLAVE_1 0x64
#define LEFT_DIR 1

#define DEBUG 1

/* pin 11 */
#define TOUCH_SENSOR 0
/* pin 12 */
#define LIGHT_SENSOR 1

volatile static int h_pos;
volatile static int h_stop;
volatile static int move_d;

void startMotor(int fd,uint8_t accel,int direction) {
  uint8_t command;
  uint8_t i;
  for (i=0x06;i<=accel;i++) {
    command = (i << 2) | (direction > 0 ? 0b10 : 0b01);
    wiringPiI2CWriteReg8(fd,0x00,command);
    delay(2);
  }
}

void stopMotor(int fd) {
  wiringPiI2CWriteReg8(fd,0x00,0x00);
  delay(100);
  wiringPiI2CWriteReg8(fd,0x00,0x03);
}

/* Interrupt handlers */
void doNothing(void) {
}

void onHTouch(void) {
  wiringPiISR(TOUCH_SENSOR, INT_EDGE_RISING,  &doNothing);
#ifdef DEBUG
  fprintf(stderr,"INT H_Touch!\n");
#endif
  --h_pos;
  h_stop = 1;
}

void onHLight(void) {
#ifdef DEBUG
  fprintf(stderr,"INT H_Light!\n");
#endif
  --h_pos;
}

/* main */
int main(int argc,char *argv[]) {
  uint8_t accel  = 0x25;
  int h_direction  = 0;
  int v_direction  = 0;
  int stop       = 0;
  int result;

  /* get opt */
  while((result=getopt(argc,argv,"a:r:l:s")) != -1) {
    switch(result){
    case 'a': // Accel
      accel = (uint8_t)strtol(optarg,NULL,0);
#ifdef DEBUG
      fprintf(stderr,"%c %x\n",result,accel);
#endif

      if (accel > 0x29 || accel < 0x06) {
	fprintf(stderr,"Invalid range of accel: 0x06 - 0x29\n");
	return -1;
      }

      break;
    case 'r': // Left n positions
      h_direction = (int)strtol(optarg,NULL,0) * LEFT_DIR * -1;
#ifdef DEBUG
      fprintf(stderr,"%c H direction = %d\n",result,h_direction);
#endif
      break;
    case 'l': // Right n positions
      h_direction = (int)strtol(optarg,NULL,0) * LEFT_DIR;
#ifdef DEBUG
      fprintf(stderr,"%c H direction = %d\n",result,h_direction);
#endif
      break;
    case 's': // force stop
      stop = 1;
      break;
    }
  }

  if (wiringPiSetup() == -1) {
    fprintf(stderr,"Cannot open wiring Pi\n");
    return -1;
  }

  /* Should I do anything? */
  if (h_direction == 0) {
    printf("H:0\n");
    return 0;
  }

  move_d = wiringPiI2CSetup(DRV8830_SLAVE_1) ;
  if (move_d < 0) {
    fprintf(stderr,"Cannot open DRV8830_SLAVE_1\n");
    return -1;
  }
  if (stop == 1) {
    stopMotor(move_d);
    printf("STOP\n");
    return 0;
  }

  h_pos = abs(h_direction);
  h_stop = h_pos == 0 ? 2 : 0;

  if (h_direction != 0) {
    /* set interrupt for sensors */
    /*
      in my implementation, 
        - the light sensor gives Low when sensored
        - the touch sensor gives High when touched
      that's why triggers varies.
     */
    wiringPiISR(TOUCH_SENSOR, INT_EDGE_RISING,  &onHTouch);
    wiringPiISR(LIGHT_SENSOR, INT_EDGE_FALLING, &onHLight);

    /* clear fault regisiter */
    wiringPiI2CWriteReg8(move_d,0x01,0x00);
    /* break */
    wiringPiI2CWriteReg8(move_d,0x00,0x03);
    // start motor 
    startMotor(move_d,accel,h_direction * LEFT_DIR);
  }

  // loop 
  while(h_stop < 2 ) {
    if (h_stop == 1) {
#ifdef DEBUG
      fprintf(stderr,"A h_stop = %d\n",h_stop);
#endif
      stopMotor(move_d);
      h_stop = 3;
    }
    if (h_pos == 0 && h_stop == 0) {
#ifdef DEBUG
      fprintf(stderr,"B h_stop = %d\n",h_stop);
#endif
      stopMotor(move_d);
      h_stop = 2;
    }
  } 
  
#ifdef DEBUG
  fprintf(stderr,"h_stop = %d\n",h_stop);
#endif

  printf("%d\n",(abs(h_direction)-h_pos)*(h_direction>0?1:-1));

  if (h_stop == 3) {
    startMotor(move_d,accel,-h_direction * LEFT_DIR);
    delay(600);
    stopMotor(move_d);
  }

  return 0;
}
