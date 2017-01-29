Pkg package format
==================

*Pkg* is the name of Shrine's package manager.

Each package ships as a manifest + one or more download formats.
The only download format currently supported is RedSea disk image (.ISO.C)

Manifest format
---------------

The manifest is a key-value format, using exactly one Tab character as delimiter. The keys are:

 - `osmin` (int - minimum supported OS version, default 0)
 - `osmax` (int - maximum OS version, default *+∞*)
 - `pkgmin` (int - minimum *Pkg* version, default *+∞*)
 - `version` (string up to 6 chars - version for display purposes, default *NULL*)
 - `release` (int - version for comparison purposes, default 0)
 - `installdir` (string, default *NULL*)
 - `iso.c` (string - see below, default *NULL*)
 - `size` (int - download size in bytes, default 0)

Currently ignored keys:

 - `name` (string - package name)
 - `website` (string)

For a package to be installable, it needs to specify at least `pkgmin`, `version`, `installdir` and a downloadable file.
The manifest can contain any other keys; *Pkg* might or might not preserve them.

`iso.c` changes meaning depending on the context.
This is somewhat confusing, which makes it a perfect fit for TempleOS.

- in repo, it's a (usually relative) URL to the package's ISO.C download
- in a downloaded package it is a filesystem path
- when building a package it specifies the output filename

`size` is ambiguous if the package provides multiple download formats. It's not a big deal.

Dependency resolution
---------------------

Soon!
