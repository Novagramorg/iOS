# Build and copy JS bridge
js:
	@RESOLVED_PATH=$$(bash Scripts/resolve-walletkit-path.sh "$(WALLETKIT_PATH)"); \
	echo "Resolved walletkit path: $$RESOLVED_PATH"; \
	bash Scripts/build-walletkit.sh "$$RESOLVED_PATH"

# Generate API models
models:
	@RESOLVED_PATH=$$(bash Scripts/resolve-walletkit-path.sh "$(WALLETKIT_PATH)"); \
	echo "Resolved walletkit path: $$RESOLVED_PATH"; \
	bash Scripts/generate-api/generate-api-models.sh "$$RESOLVED_PATH"

# Snapshot the generator output for codegen fixtures as the checked-in STANDARD
fixtures:
	@RESOLVED_PATH=$$(bash Scripts/resolve-walletkit-path.sh "$(WALLETKIT_PATH)"); \
	echo "Resolved walletkit path: $$RESOLVED_PATH"; \
	bash Scripts/generate-api/sync-fixtures.sh "$$RESOLVED_PATH"

# Regenerate codegen fixtures and diff against the STANDARD
test-fixtures:
	@RESOLVED_PATH=$$(bash Scripts/resolve-walletkit-path.sh "$(WALLETKIT_PATH)"); \
	echo "Resolved walletkit path: $$RESOLVED_PATH"; \
	bash Scripts/generate-api/test-fixtures.sh "$$RESOLVED_PATH"

# Run Swift unit tests followed by the fixture comparison
test:
	@DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
	@$(MAKE) test-fixtures WALLETKIT_PATH="$(WALLETKIT_PATH)"
