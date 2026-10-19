# Homebrew cask template. The release workflow fills in version/sha256/OWNER and pushes it to
# github.com/OWNER/homebrew-tap as Casks/barn.rb. Users then run:
#   brew install --cask OWNER/tap/barn
cask "barn" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/OWNER/barn/releases/download/v#{version}/barn-#{version}.zip"
  name "barn"
  desc "Menu bar monitor and switcher for AI coding agents"
  homepage "https://github.com/OWNER/barn"

  depends_on macos: ">= :sonoma"

  app "barn.app"
  binary "#{appdir}/barn.app/Contents/MacOS/barn"

  zap trash: [
    "~/.barn",
    "~/Library/Logs/barn.log",
    "~/Library/Preferences/dev.tony.barn.plist",
  ]
end
