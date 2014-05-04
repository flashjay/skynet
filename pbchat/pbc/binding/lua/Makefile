.PHONY : all clean

all :
	cc -g -Wall -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup -o ../../../../luaclib/protobuf.so -I../.. -I/usr/include/malloc/ -I../../../../3rd/lua -L../../../pbc/build -L../../../../3rd/lua/ pbc-lua.c -lpbc

clean :
	rm -f ../../../../luaclib/protobuf.so
