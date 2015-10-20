include ../MkRules

CPPFLAGS=-DWin32 -I. -I../../include
LINKFLAGS=

gl.a: getline.o wc_history.o

test: testgl.exe
	$(ECHO) starting testgl. Hit CRTL+BREAK to stop it.
	testgl.exe

testgl.exe: testgl.o getline.o	


clean:
	$(RM) *.o *~ *.exe *.exp gl.a
