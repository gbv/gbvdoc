# SYNOPSIS

The application is automatically started as service, listening on port 6012.

    sudo service gbvdoc {status|start|stop|restart}

# INSTALLATION

The software is released as Debian package for Ubuntu 14.04 LTS. Other Debian
based distributions *might* work too. Releases can be found at
<https://github.com/gbv/gbvdoc/releases>

To install required dependencies either use a package manager such as `gdebi`,
manually install dependencies (inspectable via `dpkg -I gbvdoc_*.deb`):

    sudo dpkg -i ...                       # install dependencies
    sudo dpkg -i gbvdoc_X.Y.Z_amd64.deb    # change X.Y.Z

After installation the service is available at localhost on port 6012. Better
put the service behind a reverse proxy to enable SSL and nice URLs! In the
following a reverse proxy mapping <http://uri.gbv.de/document/> to
<http://localhost:6012/> is assumed.

# USAGE

GBV Documents provides an interface with links to APIs for access of
metadata from databases used and/or provided by VZG.

# ADMINISTRATION

## Configuration

Config file `/etc/default/gbvdoc` only contains basic server configuration
in form of simple key-values pairs:

* `PORT`    - port number (required, 6012 by default)
* `WORKERS` - number of parallel connections (required, 5 by default).

## Logging

Log files are located at `/var/log/gbvdoc/`:

* `error.log`
* `access.log`

# CHANGES

See `debian/changelog`.

# SEE ALSO

The source code of gbvdoc is managed in a public git repository at
<https://github.com/gbv/gbvdoc>. Please report bugs and feature request at
<https://github.com/gbv/gbvdoc/issues>!

The Changelog is located in file `debian/changelog`.

Development guidelines are given in file `CONTRIBUTING.md`.
