# Copyright 2015 Jeffrey Kegler
# This file is part of Libmarpa.  Libmarpa is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Libmarpa is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Libmarpa.  If not, see
# http://www.gnu.org/licenses/.

version=`cat LIB_VERSION`

.PHONY: dummy dist doc_dist doc1_dist cm_dist test tar

dummy:
	@echo The target to make the distributions is '"dists"'

dists: dist doc_dist doc1_dist cm_dist

timestamp/work_install.stamp:
	(cd work; make install)
	test -d timestamp || mkdir timestamp
	date > timestamp/work_install.stamp

tar: timestamp/tar.stamp

timestamp/tar.stamp: timestamp/work_install.stamp
	cp work/stage/libmarpa-$(version).tar.gz .
	test -d timestamp || mkdir timestamp
	date > timestamp/tar.stamp

doc_tar: work_install
	cp work/doc/libmarpa-doc-$(version).tar.gz .

doc1_tar: work_install
	cp work/doc1/libmarpa-doc1-$(version).tar.gz .

dist: tar
	sh etc/work_to_dist.sh

doc_dist: doc_tar
	sh etc/work_to_doc_dist.sh

doc1_dist: doc1_tar
	sh etc/work_to_doc1_dist.sh

timestamp/cm_dist.stamp: tar
	perl cmake/to_dist.pl
	test -d timestamp || mkdir timestamp
	date > timestamp/cm_dist.stamp

distcheck:
	perl etc/license_check.pl  --verbose=0 `find cm_dist dist doc_dist doc1_dist -type f`

tar_clean:
	rm work/doc/*.tar.gz
	rm work/doc1/*.tar.gz
	rm work/stage/*.tar.gz

tag:
	git tag -a v$(version) -m "Version $(version)"

timestamp/cm_debug.stamp: timestamp/cm_dist.stamp
	rm -rf cm_build
	mkdir cm_build
	cd cm_build && cmake -DCMAKE_BUILD_TYPE:STRING=Debug ../cm_dist && make VERBOSE=1
	cd cm_build && make DESTDIR=../test install
	test -d timestamp || mkdir timestamp
	date > timestamp/cm_debug.stamp

test: timestamp/cm_debug.stamp
	cd do_test && cmake ../test && make VERBOSE=1
	cd do_test && ./tap/runtests -l ../test/TESTS
