DESTDIR	=	/usr
PREFIX	=	/local
CC	=	gcc
SRC	=	motor.c
OBJ	=	motor 
LIBS	=	-lwiringPi

all:		$(OBJ)
motor:	motor.c
		@echo [make move_cam]
		@$(CC) -o motor motor.c $(LIBS)

clean:
	@echo "[Clean]"
	@rm -f $(OBJ) *~ core *.bak

install:
	@echo "[Install]"
	@sudo cp $(OBJ)		$(DESTDIR)$(PREFIX)/bin
	@sudo chmod 4755 $(DESTDIR)$(PREFIX)/bin/motor
