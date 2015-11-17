TITLE   = GBV Documents
AUTHOR  = Jakob Voß, Verbundzentrale des GBV
NAME    = gbvdoc

gbvdoc.md: ../README.md ../debian/changelog
	sed -r 's!^See `debian/changelog`.!./changelog2markdown!e' ../README.md > $@

include vzgspec/Makefile

LANGUAGE=ngerman
