APP := build/Clean My Keyboard.app

.PHONY: all build run dmg icon setup-signing clean

all: build

setup-signing:
	bash scripts/setup_signing_identity.sh

build:
	bash scripts/build.sh

run: build
	open "$(APP)"

dmg:
	bash scripts/make_dmg.sh

icon:
	rm -f Resources/AppIcon.icns
	bash scripts/build.sh

clean:
	rm -rf build
	rm -f Resources/AppIcon.icns
