#!/bin/zsh

# Check if the 'fzf' command is available in the system
if ! command -v fzf &> /dev/null; then
    tput setaf 1; echo "fzf is not installed."; tput sgr0;
    exit 1;
fi

local option_list=(
	"fastlane run_all"
	"fastlane lint_swift"
	"fastlane tests"
	"fastlane build_spm"
	"fastlane build_carthage"
	"fastlane gen_docs"
	"fastlane set_version"
	"fastlane bump_version"
	" "
	"Xcode - Initialize project"
	"Xcode - Clean all build cache"
	" "
	"Carthage - Update all platforms"
	" "
	"Github - Update tag"
	"Github - Fetch remote tag"
)

local fastlane_command() {
    bundle exec $1
}

local xcode_clean() {
    xcodebuild clean || \
	xcodebuild -alltargets clean || \
	xcrun --kill-cache || \
	xcrun simctl erase all || \
	rm -rf ~/Library/Developer/Xcode/DerivedData/*;
}
local xcode_init() {
    bundle_init;
	xcode_clean;
	rm -rf ./Carthage/*;
	carthage_update;
	psl_download;
}

local carthage_update() {
    carthage update --platform macos;
	carthage update --platform ios;
	carthage update --platform tvos;
	carthage update --platform watchos;
	carthage update --platform visionos;
}

local github_update_tag() {
	# Enable error handling and exit the script on pipe failures
	set -eo pipefail
	# Check if the current branch is 'main'
	if [[ $(git rev-parse --abbrev-ref HEAD) != "main" ]]; then
		echo "Warning: You are not on the main branch. Please switch to the main branch and run again."
		exit 1
	fi
	# Find the project name
	project_name=$(find . -maxdepth 1 -name "*.xcodeproj" -exec basename {} .xcodeproj)
	# Retrieve build settings and execute a command to filter MARKETING_VERSION
	current_version=$(grep -m1 'MARKETING_VERSION' "${project_name}.xcodeproj/project.pbxproj" | sed 's/.*= //;s/;//')
	echo "Current version: $current_version"
	# If the current version is found
	if [[ $current_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		# Tags are immutable: never delete or overwrite an existing version tag
		if git tag -l | grep -q "^${current_version}$"; then
			echo "Error: Tag $current_version already exists. Bump the version instead of retagging."
			exit 1
		fi
		# Create a new tag for the current version and push it to the remote repository
		# Pushing this tag triggers the Release workflow (GitHub Release creation)
		git tag "$current_version"
		git push origin "$current_version"
	else
		# If the version could not be retrieved, display an error message
		echo "Error: Could not retrieve the version."
	fi
}

local github_fetch_remote_tag() {
    git fetch --tags --force;
}

local psl_download() {
    python update-psl.py;
}

local bundle_init() {
    rm -rf .bundle;
	rm -rf Gemfile.lock;
	gem install bundler;
	bundle install;
	bundle update;
	bundle exec fastlane add_plugin versioning;
}

local selected_option=$(printf "%s\n" "${option_list[@]}" | fzf --ansi --prompt="Select a job to execute > ")

case "$selected_option" in
    fastlane*)                                   fastlane_command $selected_option;;
	"Xcode - Initialize project")                xcode_init;;
	"Xcode - Clean all build cache")             xcode_clean;;
	"Carthage - Update all platforms")           carthage_update;;
	"Github - Update tag")                       github_update_tag;;
	"Github - Fetch remote tag")                 github_fetch_remote_tag;;
	*)                                           echo "Invalid option $selected_option" && exit 1;;
esac

exit 0;