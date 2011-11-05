default: help

VERSION := $(shell cat version)
REL := $(shell cat rel)

SUBDIRS_STAGE1 := kde-filesystem
SUBDIRS_STAGE2 := kde-settings kdelibs
SUBDIRS_STAGE3 := kdebase-workspace kdebase-runtime kdebase oxygen-icon-theme qubes-kde-dom0
SUBDIRS_STAGE4 := kdemultimedia
SUBDIRS:= $(SUBDIRS_STAGE1) $(SUBDIRS_STAGE2) $(SUBDIRS_STAGE3) $(SUBDIRS_STAGE4)

.PHONY: verify-sources get-sources clean-sources clean

all: get-sources verify-sources prep rpms srpms

verify-sources get-sources clean-sources:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -s -C $$dir $@ || exit 1;\
	done

# Even though we're serializing the builds here, I don't think we're losing
# any CPU on multi cores, because the build process should still be using
# as many cores as are available (-j). Hopefully... -- joanna
#
# Ok, one problem is with the kdebase-workspace package that
# cannot be built with SMP flag -- most likely a bug  in dependencies -- joanna

prep%:
	@for dir in $($(subst prep,SUBDIRS_STAGE,$@)); do \
		$(MAKE) -C $$dir prep || exit 1;\
	done

prep: get-sources verify-sources prep1 prep2 prep3 prep4

rpms_stage_completed%:
	@for dir in $($(subst rpms_stage_completed,SUBDIRS_STAGE,$@)); do \
		$(MAKE) -C $$dir rpms || exit 1;\
	done
	@touch $@

rpms: get-sources verify-sources rpms_stage_completed1 rpms_stage_completed2 rpms_stage_completed3 rpms_stage_completed4
	rpm --addsign rpm/*/*$(VERSION)-$(REL)*.rpm

srpms: get-sources
	@for dir in $(SUBDIRS); do \
		$(MAKE) -s -C $$dir srpm || exit 1;\
	done

clean:
	-@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean ;\
	done
	-rm -f rpms_stage_completed*

mrproper: clean
	-@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean-sources ;\
	done
	-rm -fr rpm/* srpm/*

update-repo-current:
	ln -f rpm/x86_64/*$(VERSION)-$(REL)*.rpm ../yum/current-release/current/dom0/rpm/
	ln -f rpm/noarch/*$(VERSION)-$(REL)*.rpm ../yum/current-release/current/dom0/rpm/

update-repo-unstable:
	ln -f rpm/x86_64/*$(VERSION)-$(REL)*.rpm ../yum/current-release/unstable/dom0/rpm/
	ln -f rpm/x86_64/*$(VERSION)-$(REL)*.rpm ../yum/current-release/unstable/dom0/rpm/

help:
	@echo "Usage: make <target>"
	@echo
	@echo "get-sources     Download all the KDE sources"
	@echo "verify-sources  Verify the KDE sources tarballs"
	@echo "prep            Prep all rpms (useful for checking build requirements)"
	@echo "rpms            Build all rpms"
	@echo "srpms           Create all srpms"
	@echo "all             get-sources verify-sources rpms srpms"
	@echo
	@echo "make update-repo-current  -- copy newly generated rpms to qubes yum repo"
	@echo "make update-repo-unstable -- same, but to -unstable repo"


	@echo

