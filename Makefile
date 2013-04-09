#PLACE IN THE SAME DIRECTORY AS THE .ino FILE !
#THIS WILL CREATE A build DIRECTORY (IF NOT EXISTING)
#CHANGE THE TARGET BELOW TO BUILD WITH `make all` AND UPLOAD WITH  `make upload`
#OR USE `make build/<sketchname>.tar.gz`

#Project specific config
TARGET  = 'Name your target please'
USBPORT = /dev/tty.usbmodem5d11
BUILD_DIR = ./build

#AVR distribution path
AVR_DISTRIB_ROOT = /Developer/Applications/Arduino.app/Contents/Resources/Java/hardware

#All used tools
AVRTOOLS = ${AVR_DISTRIB_ROOT}/tools/avr/bin
ARDUINOLIBS = ${AVR_DISTRIB_ROOT}/arduino/cores/arduino
ARDUINOHEADERS = ${AVR_DISTRIB_ROOT}/arduino/variants/standard
AVRDUDECONF = ${AVR_DISTRIB_ROOT}/tools/avr/etc/avrdude.conf

#Arduino libs required for the program to compile
ARDUINO_REQUIRED_LIBS = WInterrupts.c wiring.c wiring_analog.c wiring_digital.c wiring_pulse.c wiring_shift.c CDC.cpp HardwareSerial.cpp HID.cpp IPAddress.cpp main.cpp new.cpp Print.cpp Stream.cpp Tone.cpp USBCore.cpp WMath.cpp WString.cpp

#program names
CXX     = ${AVRTOOLS}/avr-g++
CC      = ${AVRTOOLS}/avr-gcc
AR      = ${AVRTOOLS}/avr-ar rcs
OBJCOPY = ${AVRTOOLS}/avr-objcopy
AVRDUDE = ${AVRTOOLS}/avrdude

#Standard Arduino Flags
CFLAGS = -Os -Wall -ffunction-sections -fdata-sections -mmcu=atmega328p -DF_CPU=16000000L -MMD -DUSB_VID=null -DUSB_PID=null -DARDUINO=101 -I${ARDUINOLIBS} -I${ARDUINOHEADERS}
CXXFLAGS = ${CFLAGS} -fno-exceptions
ELFFLAGS = -Os -Wl,--gc-sections -mmcu=atmega328p -lm
EEPFLAGS = -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0
HEXFLAGS = -O ihex -R .eeprom
UPLOADFLAGS = -C${AVRDUDECONF} -v -patmega328p -carduino -P${USBPORT} -b115200 -D

##### MAGIC BEGINS \o/ #####
SOURCES = $(addprefix build/,$(notdir ${ARDUINO_REQUIRED_LIBS}))
OBJECTS = $(addsuffix .o,$(basename ${SOURCES}))
CORE = ${BUILD_DIR}/core.a

#First (default) rule: display help
help:
	head -10 Makefile

# By default, we build .hex and .eep and retrieve it in a .tar.gz
all: ${TARGET}.tar.gz

# Create building dir
${BUILD_DIR}:
	mkdir -p $@

# Build core standard (champion) lib
${CORE} : ${OBJECTS}
	${AR} $@ $^

# Copy standard lib sources into build dir
${SOURCES} :
	for i in ${ARDUINO_REQUIRED_LIBS}; do cp ${ARDUINOLIBS}/$$i ${BUILD_DIR}/$$i;	done

# Compile a C++ file into AVR object file
${BUILD_DIR}/%.o: ${BUILD_DIR}/%.cpp
	${CXX} ${CXXFLAGS} -c -o $@ $<

# Compile a C file into AVR object file
${BUILD_DIR}/%.o: ${BUILD_DIR}/%.c
	${CC} ${CFLAGS} -c -o $@ $<

# Compile a Arudino source file into C++ file
${BUILD_DIR}/%.cpp: %.ino ${BUILD_DIR}
	echo '#include "Arduino.h"' > $@
	cat $< >> $@

# Compile standard lib and an AVR object file into an ELF file
${BUILD_DIR}/%.elf : ${BUILD_DIR}/%.o ${CORE}
	${CC} ${ELFFLAGS} -o $@ $^

# Compile an ELF file into an EEP file
${BUILD_DIR}/%.eep : ${BUILD_DIR}/%.elf
	${OBJCOPY} ${EEPFLAGS} $< $@

# Compile an ELF file into an HEX file
${BUILD_DIR}/%.hex : ${BUILD_DIR}/%.elf
	${OBJCOPY} ${HEXFLAGS} $< $@

# Build an archive with .epp and .hex
%.tar.gz : ${BUILD_DIR}/%.hex ${BUILD_DIR}/%.eep
	tar c $^ | gzip > $@

.PHONY: clean mrproper upload
upload: ${BUILD_DIR}/${TARGET}.hex ${BUILD_DIR}/${TARGET}.eep
	${AVRDUDE} ${UPLOADFLAGS} -Uflash:w:$<:i

clean:
	rm -f ${BUILD_DIR}/*.o ${BUILD_DIR}/*.d ${BUILD_DIR}/*.elf

#Just delete the build directory (use with care !)
mrproper:
	rm -f ${TARGET}.tar.gz
	rm -rf ${BUILD_DIR}