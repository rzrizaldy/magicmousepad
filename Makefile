.PHONY: app dmg install run test icon clean

app:            ## Build build/MagicMousePad.app (universal, ad-hoc signed)
	@scripts/build-app.sh

dmg: app        ## Build build/MagicMousePad-<version>.dmg
	@scripts/make-dmg.sh

install: app    ## Copy the app to /Applications and launch it
	@pkill -x MagicMousePad 2>/dev/null || true
	@rm -rf /Applications/MagicMousePad.app
	@cp -R build/MagicMousePad.app /Applications/
	@open /Applications/MagicMousePad.app
	@echo "✓ Installed to /Applications"

run:            ## Build a debug binary and run it from the terminal
	@swift run MagicMousePad

test:           ## Run unit tests
	@swift test

icon:           ## Regenerate Resources/AppIcon.icns
	@swift scripts/make-icon.swift .

clean:
	@rm -rf .build build
