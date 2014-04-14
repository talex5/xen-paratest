CROSS_COMPILE = arm-linux-gnueabihf-
CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy

all: paratest.img

paratest.img: arm32.o paratest.lds
	#$(LD) -r $(LDFLAGS) $(HEAD_OBJ) $(APP_O) $(OBJS) $(LDARCHLIB) $(LDLIBS) -o $@.o
	#$(OBJCOPY) -w -G $(GLOBAL_PREFIX)* -G _start $@.o $@.o
	$(LD) $(LDFLAGS) -T paratest.lds arm32.o -o tmp.o
	$(OBJCOPY) -O binary tmp.o paratest.img

test: paratest.img
	scp paratest.img root@linaro-developer:
	ssh root@linaro-developer "xl destroy paratest; xl create paratest.cfg; sleep 1; xl destroy paratest"
