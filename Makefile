VERSION := $(shell cat version)
SUBDIRS = klibc ash ipconfig nfsmount utils kinit gzip
SRCROOT = .

all:

rpmbuild = $(shell which rpmbuild 2>/dev/null || which rpm)

klibc.spec: klibc.spec.in version
	sed -e 's/@@VERSION@@/$(VERSION)/g' < $< > $@

.PHONY: rpm
rpm: klibc.spec
	+$(rpmbuild) -bb klibc.spec --target=$(ARCH)

$(CROSS)klibc.config: Makefile
	rm -f $@
	echo 'ARCH=$(ARCH)' >> $@
	echo 'CROSS=$(CROSS)' >> $@
	echo 'KCROSS=$(KCROSS)' >> $@
	echo "CC=$(shell bash -c 'type -p $(CC)')" >> $@
	echo "LD=$(shell bash -c 'type -p $(LD)')" >> $@
	echo 'REQFLAGS=$(filter-out -I%,$(REQFLAGS))' >> $@
	echo 'OPTFLAGS=$(OPTFLAGS)' >> $@
	echo 'LDFLAGS=$(LDFLAGS)' >> $@
	echo "STRIP=$(shell bash -c 'type -p $(STRIP)')" >> $@
	echo 'STRIPFLAGS=$(STRIPFLAGS)' >> $@
	echo 'EMAIN=$(EMAIN)' >> $@
	echo 'BITSIZE=$(BITSIZE)' >> $@
	echo 'INSTALLDIR=$(INSTALLDIR)' >> $@

$(CROSS)klcc: klcc.in $(CROSS)klibc.config makeklcc.pl
	$(PERL) makeklcc.pl klcc.in $(CROSS)klibc.config \
		$(shell bash -c 'type -p $(PERL)') > $@ || ( rm -f $@ ; exit 1 )
	chmod a+x $@

%: local-%
	@set -e; for d in $(SUBDIRS); do $(MAKE) -C $$d $@; done

local-all: $(CROSS)klcc

local-clean:
	rm -f klibc.config klcc

local-spotless:
	rm -f klibc.spec *~ tags

local-install: $(CROSS)klcc
	mkdir -p $(INSTALLROOT)$(bindir)
	mkdir -p $(INSTALLROOT)$(mandir)/man1
	mkdir -p $(INSTALLROOT)$(SHLIBDIR)
	mkdir -p $(INSTALLROOT)$(INSTALLDIR)
	-rm -rf $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)include
	mkdir -p $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)include
	mkdir -p $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)lib
	mkdir -p $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)bin
	set -xe ; for d in linux asm-$(ARCH) asm-generic $(ASMARCH); do \
	  mkdir -p $(INSTALLROOT)$(INSTALLDIR)/$(CROSS)include/$$d ; \
	  cp -rfL $(KRNLSRC)/include/$$d/.  $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)include/$$d/. ; \
	  cp -rfL $(KRNLOBJ)/include/$$d/.  $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)include/$$d/. ; \
	  [ ! -d $(KRNLOBJ)/include2/$$d ] || \
	    cp -rfL $(KRNLOBJ)/include2/$$d/. $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)include/$$d/. ; \
	done
	cd $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)include && ln -sf asm-$(ARCH) asm
	cp -rf include/. $(INSTALLROOT)$(INSTALLDIR)/$(KCROSS)include/.
	$(INSTALL_DATA) klcc.1 $(INSTALLROOT)$(mandir)/man1/$(KCROSS)klcc.1
	$(INSTALL_EXEC) $(KCROSS)klcc $(INSTALLROOT)$(bindir)

-include MCONFIG
