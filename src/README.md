motor.c
=======

A robot controlling programs using DRV8830 and Raspberry pi.

There are a DRV8830 on an I2C bus (0x64), and two switches and a photo
reflector are connected to 2 GPIO pins.  The motors run until a photo
reflector or a switch senses something.

INSTALL
--------

```
$ make; make install
```

This will install "motor" into /usr/local/bin.
