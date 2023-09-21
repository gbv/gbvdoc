MAINSRC:=lib/App/GBVDoc.pm
CONTROL:=debian/control

# parse debian control file and changelog
C:=(
J:=)
PACKAGE:=$(shell perl -ne 'print $$1 if /^Package:\s+(.+)/;' < $(CONTROL))
ARCH   :=$(shell perl -ne 'print $$1 if /^Architecture:\s+(.+)/' < $(CONTROL))
DEPENDS:=$(shell perl -ne '\
	next if /^\#/; $$p=(s/^Depends:\s*/ / or (/^ / and $$p));\
	s/,|\n|\([^$J]+\)//mg; print if $$p' < $(CONTROL))
VERSION:=$(shell perl -ne '/^.+\s+[$C](.+)[$J]/ and print $$1 and exit' < debian/changelog)
RELEASE:=${PACKAGE}_${VERSION}_${ARCH}.deb

# show configuration
info:
	@echo "Release: $(RELEASE)"
	@echo "Depends: $(DEPENDS)"

version:
	@perl -p -i -e 's/^our\s+\$$VERSION\s*=.*/our \$$VERSION="$(VERSION)";/' $(MAINSRC)
	@perl -p -i -e 's/^our\s+\$$NAME\s*=.*/our \$$NAME="$(PACKAGE)";/' $(MAINSRC)

# build Debian package
package: version tests
	dpkg-buildpackage -b -us -uc -rfakeroot
	mv ../$(PACKAGE)_$(VERSION)_*.deb .

# install required toolchain and Debian packages
dependencies:
	apt-get -y install fakeroot dpkg-dev debhelper
	apt-get -y install $(DEPENDS)

# install required Perl packages
local: cpanfile
	cpanm -l local --skip-satisfied --installdeps --notest .

# run locally
run: local
	plackup -Ilib -Ilocal/lib/perl5 -r app.psgi

# check sources for syntax errors
code:
	@find lib -iname '*.pm' -exec perl -c -Ilib -Ilocal/lib/perl5 {} \;

# run tests
tests: local
	PLACK_ENV=tests prove -Ilocal/lib/perl5 -l -v
