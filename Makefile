#Targets: 
# libdso.so     build shared library
#
# app           build app   (shared druntime/phobos/libdso)
# sapp          build sapp  (static druntime/phobos/libdso)
# sdapp         build sdapp (static druntime/phobos, shared libdso)
#
# test          run app     (shared druntime/phobos/libdso)
# stest         run sapp    (static druntime/phobos/libdso)
# sdtest        run sdapp   (static druntime/phobos, shared libdso)
#
# ldd           ldd app     (shared druntime/phobos/libdso)
# sldd          ldd sapp    (static druntime/phobos/libdso)
# sdldd         ldd sdapp   (static druntime/phobos, shared libdso)

all: app

D_EXTRA_FLAGS=-funittest -fproperty

libdso.so: dso/dso.d Makefile
	gdc $(D_EXTRA_FLAGS) dso/dso.d -shared -o libdso.so -nophoboslib

app: libdso.so app.d dso.di Makefile
	gdc $(D_EXTRA_FLAGS) app.d -lgdruntime -ldso -L. /opt/gdc/lib/dmain2.o -o app

sapp: app.d dso/dso.d Makefile
	gdc $(D_EXTRA_FLAGS) app.d dso/dso.d -nophoboslib -Wl,-static -lgphobos2 -Wl,-Bdynamic -lpthread -o sapp
    
sdapp: libdso.so app.d dso.di Makefile
	gdc $(D_EXTRA_FLAGS) app.d -nophoboslib -Wl,-static -lgphobos2 -Wl,-Bdynamic -lpthread -ldso -L. -o sdapp

clean: Makefile
	rm -f app
	rm -f sapp
	rm -f libdso.so

test: app Makefile
	LD_LIBRARY_PATH=/opt/gdc/lib:. ./app

stest: sapp Makefile
	./sapp

sdtest: sdapp Makefile
	LD_LIBRARY_PATH=. ./sdapp

ldd: app Makefile
	LD_LIBRARY_PATH=/opt/gdc/lib:. ldd ./app

sldd: sapp Makefile
	ldd ./sapp

sdldd: sdapp Makefile
	LD_LIBRARY_PATH=. ldd ./sdapp
